const fs=require('fs');const bytes=fs.readFileSync('tmp/bilingual-test.log');const s=bytes.toString(bytes[0]===255?'utf16le':'utf8');
for(const block of s.split('══╡')) {
 if(!block.includes('EXCEPTION CAUGHT'))continue;
 console.log(block.slice(0,500));
 console.log((block.match(/The test description was:[\s\S]{0,220}/)||[''])[0]);
 console.log((block.match(/The relevant error-causing widget was:[\s\S]{0,220}/)||[''])[0]);
 console.log((block.match(/#4[\s\S]{0,300}/)||[''])[0]);
}
console.log(s.slice(-1000));
