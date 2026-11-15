let priceChart, volumeChart, hoveredIndex = null, pendingCrosshairFrame = 0;
const $ = id => document.getElementById(id);
const format = new Intl.NumberFormat('zh-TW', { maximumFractionDigits: 2 });
const marketCache = new Map();
let activeRequest = 0;

async function marketDataFor(symbol, period, force = false) {
  const cacheKey = `${symbol}:${period}`;
  if (!force && marketCache.has(cacheKey)) return marketCache.get(cacheKey);
  const ranges = { 22: '1mo', 66: '3mo', 132: '6mo', 252: '1y', 504: '2y', 900: '5y' };
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?range=${ranges[period]}&interval=1d&events=history`;
  const response = await fetch(url);
  if (!response.ok) throw new Error(`行情服務回應 ${response.status}`);
  const result = (await response.json()).chart?.result?.[0];
  const quote = result?.indicators?.quote?.[0];
  if (!result?.timestamp || !quote) throw new Error('找不到此股票代碼的日線資料');
  const rows = result.timestamp.map((seconds, index) => ({ date: new Date(seconds * 1000), open: quote.open[index], high: quote.high[index], low: quote.low[index], close: quote.close[index], volume: quote.volume[index] }))
    .filter(row => [row.open, row.high, row.low, row.close, row.volume].every(Number.isFinite));
  if (rows.length < 2) throw new Error('可用交易資料不足');
  const payload = { rows, source: 'Yahoo Finance 日線資料', isFallback: false };
  marketCache.set(cacheKey, payload);
  return payload;
}
function ma(rows, n) {
  let sum = 0;
  return rows.map((row, index) => { sum += row.close; if (index >= n) sum -= rows[index - n].close; return index < n - 1 ? null : sum / n; });
}
function metric(title, value, delta='', asOf='') { return `<article class="metric"><label>${title}</label><strong>${value}</strong>${delta}${asOf ? `<small class="as-of">${asOf}</small>` : ''}</article>`; }
const dateLabel = date => new Intl.DateTimeFormat('zh-TW', { timeZone: 'Asia/Taipei', month: 'numeric', day: 'numeric' }).format(date);
function profileFor(symbol) {
  const profiles = {
    '0050.TW': ['元大台灣卓越50 ETF', '追蹤臺灣50指數，主要涵蓋台灣上市市值前 50 大公司。常見核心成分包含台積電、鴻海、聯發科等；實際持股與權重會依指數與基金公告調整。'],
    '2330.TW': ['台灣積體電路製造股份有限公司', '晶圓代工業者，主要提供先進與成熟製程的半導體製造服務。公司基本面與產業資訊應以法說會、公開資訊觀測站及公司公告為準。'],
    '2317.TW': ['鴻海精密工業股份有限公司', '電子製造服務業者，業務涵蓋消費電子、雲端網通與電動車等領域。請以公司公告與公開資訊觀測站資料確認最新情況。']
  };
  return profiles[symbol] || [`${symbol} 標的介紹`, '此預覽版尚未串接完整公司資料庫。請透過公司公告、公開資訊觀測站與基金／指數官方文件確認業務內容、成分股或持股比重。'];
}
async function redraw({ force = false } = {}) {
  const rawSymbol = $('symbol').value.trim().toUpperCase();
  const requestId = ++activeRequest, symbol = /^[A-Z0-9.^-]{1,12}$/.test(rawSymbol) ? rawSymbol : '0050.TW', period = $('period').value;
  $('symbol').value = symbol; $('refresh').disabled = true; $('notice').classList.remove('warning'); $('notice').textContent = '正在讀取 Yahoo Finance 日線資料…';
  let payload;
  try { payload = await marketDataFor(symbol, period, force); }
  catch (error) {
    if (requestId !== activeRequest) return;
    $('refresh').disabled = false; $('notice').classList.add('warning'); $('notice').textContent = `無法取得 Yahoo Finance 資料：${error.message}`;
    showDataError();
    return;
  }
  if (requestId !== activeRequest) return;
  $('refresh').disabled = false; $('notice').textContent = payload.source; $('notice').classList.remove('warning');
  renderDashboard(symbol, payload.rows);
}
function showDataError() {
  priceChart?.destroy(); volumeChart?.destroy(); priceChart = undefined; volumeChart = undefined;
  $('metrics').innerHTML = '<article class="metric"><label>行情資料</label><strong>暫時無法載入</strong><small class="as-of">請確認網路連線後重新整理。</small></article>';
  $('company-card').innerHTML = ''; $('analysis').innerHTML = '';
}
function renderDashboard(symbol, rows) {
  const last=rows.at(-1), previous=rows.at(-2); const change=last.close-previous.close, percent=change/previous.close*100, positive=change>=0, lastDate = `${dateLabel(last.date)} 最後交易日`;
  $('chart-title').textContent = `${symbol} K 線與均線走勢圖`;
  $('metrics').innerHTML = metric('最新日收盤價', last.close.toFixed(2), `<span class="delta ${positive?'up':'down'}">${positive?'+':''}${change.toFixed(2)} (${positive?'+':''}${percent.toFixed(2)}%)</span>`, lastDate) + metric('開盤價',last.open.toFixed(2),'',lastDate) + metric('最高價',last.high.toFixed(2),'',lastDate) + metric('最低價',last.low.toFixed(2),'',lastDate) + metric('成交量（張）',format.format(Math.round(last.volume/1000)),'',lastDate);
  const [profileTitle, profileText] = profileFor(symbol);
  $('company-card').innerHTML = `<h2>${profileTitle}</h2><p>${profileText}</p><p><strong>提醒：</strong>成分股、權重與公司資料會變動，請以官方最新公告為準。</p>`;
  const ma5=ma(rows,5),ma20=ma(rows,20),ma60=ma(rows,60), labels=rows.map(x=>`${x.date.getMonth()+1}/${x.date.getDate()}`);
  const trend=last.close>ma5.at(-1)&&ma5.at(-1)>ma20.at(-1)?['趨勢分析：多頭偏強','最新價站上 MA5 與 MA20，短中期趨勢偏強。','#5daaff']:last.close<ma5.at(-1)&&ma5.at(-1)<ma20.at(-1)?['趨勢分析：空頭修整','價格低於短期均線，留意下方均線支撐。','#ff6363']:['趨勢分析：高檔震盪','價格與短中期均線交錯，等待方向突破。','#5daaff'];
  const alignment=ma5.at(-1)>=ma20.at(-1)&&ma20.at(-1)>=ma60.at(-1)?'多頭排列':ma5.at(-1)<=ma20.at(-1)&&ma20.at(-1)<=ma60.at(-1)?'空頭排列':'均線糾結整理';
  const newsUrl = `https://news.google.com/search?q=${encodeURIComponent(symbol + ' 股票')}&hl=zh-TW&gl=TW&ceid=TW%3Azh-Hant`;
  const plainAlignment = alignment === '多頭排列' ? '短、中、長期平均價格依序向上，趨勢相對偏強。' : alignment === '空頭排列' ? '短、中、長期平均價格依序向下，趨勢相對偏弱。' : '短、中、長期平均價格很接近，市場暫時沒有明確方向。';
  $('analysis').innerHTML = [trend,[`均線狀態：${alignment}`,`${plainAlignment}（MA5 ${ma5.at(-1).toFixed(2)}／MA20 ${ma20.at(-1).toFixed(2)}／MA60 ${ma60.at(-1).toFixed(2)}）`,'#af83ff'],[last.close>=ma5.at(-1)?'操作與新聞脈絡':'等待止跌與新聞確認','技術面僅提供觀察方向。決策前請比對公司公告、產業消息與來源可信度。','#35c993',`<a class="news-link" href="${newsUrl}" target="_blank" rel="noreferrer">查看 ${symbol} 最新新聞 ↗</a>`]].map(x=>`<article class="analysis-card" style="--accent:${x[2]}"><h3>${x[0]}</h3><p>${x[1]}</p>${x[3]||''}</article>`).join('');
  priceChart?.destroy(); volumeChart?.destroy(); hoveredIndex = null; const line = (label,data,color) => ({label,data,borderColor:color,borderWidth:1.5,pointRadius:0,tension:.2,spanGaps:true});
  priceChart=new Chart($('price-chart'),{type:'line',data:{labels,datasets:[{label:'收盤價',data:rows.map(x=>x.close),borderColor:'#dceafe',borderWidth:1,pointRadius:0,tension:.1,fill:false},line('MA5',ma5,'#5daaff'),line('MA20',ma20,'#ffb44f'),line('MA60',ma60,'#af83ff')]},options:options(false, rows),plugins:[syncCrosshair]});
  volumeChart=new Chart($('volume-chart'),{type:'bar',data:{labels,datasets:[{label:'成交量',data:rows.map(x=>x.volume),backgroundColor:rows.map(x=>x.close>=x.open?'#ff6363aa':'#35c993aa'),borderRadius:2}]},options:options(true, rows),plugins:[syncCrosshair]});
}
const syncCrosshair = {
  id: 'syncCrosshair',
  afterEvent(chart, args) {
    const event = args.event;
    const previousIndex = hoveredIndex;
    if (event.type === 'mouseout') hoveredIndex = null;
    else if (event.type === 'mousemove') {
      const x = chart.scales.x;
      if (event.x >= x.left && event.x <= x.right) hoveredIndex = Math.max(0, Math.min(chart.data.labels.length - 1, Math.round(x.getValueForPixel(event.x))));
    }
    if (previousIndex !== hoveredIndex) scheduleCrosshairDraw();
  },
  afterDraw(chart) {
    if (hoveredIndex === null) return;
    const x = chart.scales.x.getPixelForValue(hoveredIndex), { ctx, chartArea } = chart;
    ctx.save(); ctx.beginPath(); ctx.moveTo(x, chartArea.top); ctx.lineTo(x, chartArea.bottom); ctx.lineWidth = 1; ctx.strokeStyle = '#b9d8ffcc'; ctx.setLineDash([4, 4]); ctx.stroke(); ctx.restore();
  }
};
function scheduleCrosshairDraw() {
  if (pendingCrosshairFrame) return;
  pendingCrosshairFrame = requestAnimationFrame(() => { pendingCrosshairFrame = 0; [priceChart, volumeChart].filter(Boolean).forEach(chart => chart.draw()); });
}
function options(compact, rows) { return {responsive:true,maintainAspectRatio:false,animation:false,normalized:true,interaction:{mode:'index',intersect:false},plugins:{legend:{display:false},tooltip:{displayColors:false,padding:12,cornerRadius:10,animation:false,titleFont:{size:14,weight:'700'},bodyFont:{size:13,weight:'600'},backgroundColor:'#0b1b30',titleColor:'#ffffff',bodyColor:'#dcecff',callbacks:{title: items => `${dateLabel(rows[items[0].dataIndex].date)}（交易日）`,label: item => compact ? `成交量  ${format.format(item.raw)} 股` : `${item.dataset.label}  ${Number(item.raw).toFixed(2)}`,afterBody: items => compact ? [] : (() => { const row=rows[items[0].dataIndex]; return [`開盤 ${row.open.toFixed(2)}　最高 ${row.high.toFixed(2)}`,`最低 ${row.low.toFixed(2)}　收盤 ${row.close.toFixed(2)}`]; })()}}},scales:{x:{grid:{display:false},ticks:{color:'#92a4bb',maxTicksLimit:7,autoSkip:true}},y:{grid:{color:'#233650'},ticks:{color:'#92a4bb',callback:v=>compact?`${Math.round(v/1000000)}M`:v}}}}; }
function tick(){ $('clock').textContent = new Intl.DateTimeFormat('zh-TW',{dateStyle:'medium',timeStyle:'medium',timeZone:'Asia/Taipei'}).format(new Date()); }
$('refresh').addEventListener('click',() => redraw({ force: true })); $('period').addEventListener('change',() => redraw()); $('symbol').addEventListener('keydown',e=>{if(e.key==='Enter')redraw({ force: true })}); tick();setInterval(tick,1000);redraw();
