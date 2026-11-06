const fs=require('fs');
const {PDFiumLibrary}=require('../tmp/pdfqa/node_modules/@hyzyla/pdfium/dist/index.cjs');
const sharp=require('../tmp/pdfqa/node_modules/sharp');
(async()=>{
 const library=await PDFiumLibrary.init();
 for(const name of ['nepali-a4','nepali-58','nepali-80']) {
  const doc=await library.loadDocument(fs.readFileSync(`tmp/pdfs/${name}.pdf`));
  for(const page of doc.pages()) {
   const result=await page.render({scale:2,render:async o=>sharp(o.data,{raw:{width:o.width,height:o.height,channels:4}}).png().toBuffer()});
   fs.writeFileSync(`tmp/pdfs/${name}-${page.number}.png`,result.data);
   console.log(`${name}: ${page.number}`);page.close();
  }
  doc.destroy();
 }
 library.destroy();
})().catch(e=>{console.error(e);process.exitCode=1;});
