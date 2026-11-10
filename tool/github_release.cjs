// GitHub publishing helper. The existing Git credential is scoped to github.com,
// held only in process memory, and never written to arguments, files or output.
const fs=require('node:fs');
const path=require('node:path');
const {execFileSync}=require('node:child_process');
const repo='DevSidh/Ram-Prasad-Kirana-';
async function main(){
  let token;
  try {
    const credential=execFileSync('rtk',['proxy','git','credential','fill'],{
      input:`protocol=https\nhost=github.com\npath=${repo}.git\n\n`,encoding:'utf8',
      env:{...process.env,GIT_TERMINAL_PROMPT:'0',GCM_INTERACTIVE:'Never'},stdio:['pipe','pipe','pipe'],timeout:20000,
    });
    token=credential.split(/\r?\n/).find(line=>line.startsWith('password='))?.slice(9);
  } catch (_) {throw Error('GitHub credential unavailable through the configured Git credential helper.');}
  if(!token)throw Error('No GitHub publishing credential was returned.');
  const api=async(endpoint,options={})=>{
    const response=await fetch('https://api.github.com'+endpoint,{...options,headers:{
      Accept:'application/vnd.github+json','X-GitHub-Api-Version':'2026-03-10',Authorization:`Bearer ${token}`,...options.headers}});
    if(!response.ok)throw Error(`GitHub ${options.method??'GET'} ${endpoint.split('?')[0]} failed (HTTP ${response.status}).`);
    return response.status===204?null:response.json();
  };
  const [command,tag,file]=process.argv.slice(2);
  if(command==='repos'){
    const repositories=await api('/user/repos?per_page=100&sort=updated');
    console.log(JSON.stringify(repositories.map(r=>({name:r.full_name,branch:r.default_branch,homepage:r.homepage})),null,2));return;
  }
  if(command==='publish'){
    const releases=await api(`/repos/${repo}/releases?per_page=100`);
    const release=releases.find(r=>r.tag_name===tag);
    if(!release)throw Error('Release not found.');
    if(!release.assets.some(a=>a.name.endsWith('.apk')) || !release.assets.some(a=>a.name.endsWith('.zip')))throw Error('Upload both APK and Windows ZIP before publishing.');
    const published=await api(`/repos/${repo}/releases/${release.id}`,{method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify({draft:false,make_latest:'true'})});
    console.log(JSON.stringify({tag:published.tag_name,url:published.html_url,draft:published.draft}));return;
  }
  if(command==='account'){
    const user=await api('/user');const repository=await api('/repos/'+repo);
    console.log(JSON.stringify({login:user.login,canPush:repository.permissions?.push??false}));return;
  }
  if(command==='status'){
    const runs=await api(`/repos/${repo}/actions/runs?per_page=5`);
    console.log(JSON.stringify(runs.workflow_runs.map(r=>({id:r.id,name:r.name,branch:r.head_branch,status:r.status,conclusion:r.conclusion,url:r.html_url,sha:r.head_sha})),null,2));return;
  }
  if(command==='run'){
    if(!/^\d+$/.test(tag??''))throw Error('Provide a workflow run ID.');
    const run=await api(`/repos/${repo}/actions/runs/${tag}`);
    const jobs=await api(`/repos/${repo}/actions/runs/${tag}/jobs`);
    console.log(JSON.stringify({status:run.status,conclusion:run.conclusion,url:run.html_url,
      jobs:jobs.jobs.map(job=>({id:job.id,status:job.status,conclusion:job.conclusion,
        steps:job.steps.map(step=>({name:step.name,status:step.status,conclusion:step.conclusion}))}))},null,2));return;
  }
  if(command==='logs'){
    if(!/^\d+$/.test(tag??''))throw Error('Provide a job ID.');
    const response=await fetch(`https://api.github.com/repos/${repo}/actions/jobs/${tag}/logs`,{
      headers:{Authorization:`Bearer ${token}`,Accept:'application/vnd.github+json'}});
    if(!response.ok)throw Error(`Job logs unavailable (HTTP ${response.status}).`);
    const lines=(await response.text()).split(/\r?\n/);
    if(file==='errors'){
      const indexes=new Set();
      lines.forEach((line,i)=>{if(/EXCEPTION CAUGHT|Expected:|test description was:/.test(line)){
        for(let n=Math.max(0,i-2);n<Math.min(lines.length,i+14);n++)indexes.add(n);
      }});
      console.log([...indexes].sort((a,b)=>a-b).map(i=>lines[i]).join('\n'));return;
    }
    console.log(lines.slice(-180).join('\n'));return;
  }
  if(command==='release'){
    const releases=await api(`/repos/${repo}/releases?per_page=30`);
    const release=releases.find(value=>value.tag_name===tag);
    if(!release)throw Error('Release not found.');
    console.log(JSON.stringify({tag:release.tag_name,draft:release.draft,url:release.html_url,
      assets:release.assets.map(a=>({name:a.name,size:a.size,url:a.browser_download_url,digest:a.digest}))},null,2));return;
  }
  if(command==='create'){
    if(!tag || !/^v\d+\.\d+\.\d+$/.test(tag) || !file)throw Error('Provide a version tag and release notes file.');
    const release=await api(`/repos/${repo}/releases`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({
      tag_name:tag,name:`FastStore ${tag} — Android and Windows`,body:fs.readFileSync(file,'utf8'),draft:true,prerelease:false,
    })});console.log(JSON.stringify({id:release.id,url:release.html_url}));return;
  }
  if(command==='upload'){
    // GitHub's tag lookup can omit drafts even with authenticated access.
    const releases=await api(`/repos/${repo}/releases?per_page=100`);
    const release=releases.find(value=>value.tag_name===tag);
    if(!release)throw Error('No release with this tag exists, including drafts.');
    const name=path.basename(file);
    if(release.assets.some(a=>a.name===name))throw Error('An asset with this name already exists; inspect before replacement.');
    const bytes=fs.readFileSync(file);
    const endpoint=release.upload_url.split('{')[0]+'?name='+encodeURIComponent(name);
    if(new URL(endpoint).hostname!=='uploads.github.com')throw Error('Unexpected upload destination.');
    const response=await fetch(endpoint,{method:'POST',headers:{Authorization:`Bearer ${token}`,
      'Content-Type':name.endsWith('.apk')?'application/vnd.android.package-archive':name.endsWith('.zip')?'application/zip':name.endsWith('.json')?'application/json':'application/octet-stream','Content-Length':String(bytes.length)},body:bytes});
    if(!response.ok)throw Error(`GitHub release asset upload failed (HTTP ${response.status}).`);
    const asset=await response.json();console.log(JSON.stringify({name:asset.name,size:asset.size,url:asset.browser_download_url}));return;
  }
  throw Error('Supported commands: account, status, run, logs, release, create, upload.');
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
