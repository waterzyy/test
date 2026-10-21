const assert=require('node:assert/strict'),C=require('./core-test.js');let checks=0;function check(fn){fn();checks++;}
check(()=>assert.equal(C.cards.length,28));check(()=>assert.equal(new Set(C.cards.map(c=>c.id)).size,28));
for(const c of C.cards)check(()=>{assert.equal(c.steps.length,3);assert.ok(c.title&&c.intro&&c.twist&&C.categories[c.category]);assert.ok(c.minutes>0&&c.minutes<60);});
check(()=>assert.equal(C.pool('all',false,false).length,24));check(()=>assert.equal(C.pool('all',true,false).length,28));check(()=>assert.ok(C.pool('road',false,true).every(c=>c.category==='road'&&!c.experimental&&c.minutes<=10)));
check(()=>assert.equal(C.pick([],[]),null));check(()=>assert.equal(C.pick(C.cards,[C.cards[0].id],()=>0).id,C.cards[1].id));check(()=>assert.ok(C.pick(C.cards,C.cards.map(c=>c.id))));check(()=>assert.equal(C.pick(C.cards,[],()=>1).id,C.cards.at(-1).id));
check(()=>assert.equal(C.remaining({running:true,end:12000,left:20000},15000),0));check(()=>assert.equal(C.remaining({running:false,left:7000},15000),7000));
check(()=>{const s=C.defaultState();s.active='delivery';s.timer={running:true,left:480000,end:500000};const restored=C.restore(JSON.parse(JSON.stringify(s)),30000);assert.equal(C.remaining(restored.timer,30000),470000);const expired=C.restore(s,600000);assert.equal(expired.timer.running,false);assert.equal(expired.timer.left,0);});
check(()=>{const s=C.defaultState();s.active='delivery';assert.equal(C.complete(s,100),true);assert.equal(C.complete(s,101),false);assert.deepEqual(C.stats(s.history),{wins:1,points:120});assert.equal(s.turn,1);assert.equal(s.timer,null);});
for(const value of [null,[],42,'bad',{active:'not-real',names:[false,{}],history:[null,{id:'delivery',at:Infinity}]},{active:'delivery',timer:{running:true,left:-1,end:4}}])check(()=>{const s=C.restore(value,1000);assert.equal(s.names.length,2);assert.equal(s.timer,null);assert.equal(s.history.length,0);});
check(()=>{const s=C.restore({history:Array.from({length:1100},()=>({id:'delivery',at:10})),recent:Array(50).fill('delivery')},1000);assert.equal(s.history.length,1000);assert.equal(s.recent.length,8);});
check(()=>assert.equal(C.restore({category:'__proto__'},1000).category,'all'));
check(()=>assert.equal(C.cleanName('  Брат  ','fallback'),'Брат'));check(()=>assert.equal(C.cleanName('', 'fallback'),'fallback'));check(()=>assert.equal(C.cleanName('x'.repeat(100),'fallback').length,24));
console.log(checks+' core checks passed');
