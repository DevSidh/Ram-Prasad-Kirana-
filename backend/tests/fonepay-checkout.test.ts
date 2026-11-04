import assert from 'node:assert/strict';
import express from 'express';
import type { PrismaClient } from '@prisma/client';
import type { InventoryService } from '../src/services/inventory.js';
import { createAdminBillingRouter } from '../src/routes/admin-billing.js';
import type { FonepayGateway } from '../src/services/fonepay-gateway.js';

// Local request/DB fixtures only. Never calls Fonepay or a real database.
async function main() {
  let saved:any=null, writes=0, consumes=0, numbers=0;
  const tx={
    posShift:{findFirst:async()=>({id:'shift',cashierId:'operator'})},
    product:{findMany:async()=>[{id:'p',name:'Test product',sku:'TEST',price:100,unitLabel:'pcs',inventory:{totalStock:10,reservedStock:0}}]},
    posSale:{findUnique:async()=>saved?{...saved,shift:{cashierId:'operator'}}:null,
      create:async({data}:any)=>{
        writes++;saved={...data,id:'checkout-test',createdAt:new Date(),refundedAmount:0,
          items:data.items.create.map((item:any)=>({...item,id:'line'})),paymentCollections:[]};return saved;
      }},
    invoiceSequence:{upsert:async()=>{numbers++;return{nextNumber:1};}},
  };
  const prisma={$transaction:async(work:any)=>work(tx)} as unknown as PrismaClient;
  const inventory={consumeStockForPosSale:async()=>{consumes++;}} as unknown as InventoryService;
  const gateway:FonepayGateway={environment:'sandbox',merchantCode:'TEST',
    create:async()=>{throw Error('Not used');},verify:async()=>{throw Error('Not used');}};
  const app=express();app.use(express.json());app.use((_,res,next)=>{
    res.locals.authenticatedUserId='operator';res.locals.authenticatedUserRole='ADMIN';next();});
  app.use('/disabled',createAdminBillingRouter(prisma,inventory));
  app.use('/fixture',createAdminBillingRouter(prisma,inventory,undefined,()=>gateway));
  const server=app.listen(0);await new Promise<void>(resolve=>server.once('listening',resolve));
  try {
    const address=server.address();assert(address && typeof address!=='string');
    const base=`http://127.0.0.1:${address.port}`;
    const payload={idempotencyKey:'550e8400-e29b-41d4-a716-446655440099',items:[{productId:'p',quantity:1}],
      discount:11.5,vatRate:13,paymentMethod:'FONEPAY',quote:{expectedTotal:100.01,unitPrices:{p:100}}};
    const post=(path:string,body=payload)=>fetch(base+path,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});
    assert.equal((await post('/disabled/sales')).status,503);assert.equal(writes,0);
    const response=await post('/fixture/sales');assert.equal(response.status,201);
    const body=await response.json() as any;
    assert.equal(body.sale.status,'CHECKOUT');assert.equal(body.sale.paymentStatus,'PENDING');
    assert.equal(body.sale.total,100.01);assert.equal(body.sale.paidAmount,0);
    assert.equal(saved.invoiceNumber,null);assert.equal(numbers,0);assert.equal(consumes,0);
    assert.equal(saved.paymentCollections.length,0);
    assert.equal((await post('/fixture/sales')).status,200);assert.equal(writes,1);
    assert.equal((await post('/fixture/sales',{...payload,quote:{expectedTotal:100.02,unitPrices:{p:100}}})).status,409);
    assert.equal(consumes,0);assert.equal(numbers,0);
    assert.equal((await post('/fixture/sales',{...payload,paidAmount:100.01} as any)).status,400);
  } finally {await new Promise<void>(resolve=>server.close(()=>resolve()));}
  console.log('Fonepay checkout fixtures passed: disabled live adapter, exact quoted totals, pending-only draft, no stock/number/collection, replay and revision guard. NOT Fonepay UAT.');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
