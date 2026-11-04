//+------------------------------------------------------------------+
//|                                                                  |
//|                                                                  |
//|                                                                  |
//|                    A L P H E N T R A   A I                       |
//|                                                                  |
//|                     TRADE BEYOND LIMITS.                         |
//|                                                                  |
//|                     SMART TP/SL ALGO EA                          |
//|  --------------------------------------------------------------  |
//|                                                                  |
//|  PRODUCT  : SMART TP/SL                                          |
//|  DEVELOPER: ALPHENTRA AI                                         |
//|  ENGINE   : EMA 5/13 CROSSOVER + ATR 14 (PINE SCRIPT PORT)       |
//|                                                                  |
//|  FEATURES  : Latest Signal Only, TP1/TP2/TP3, Alerts & Auto EA   |
//|                                                                  |
//|                                                                  |
//|  COPYRIGHT: Alphentra Ai                                         |
//|  WEBSITE  : https://alphentra.app/                               |
//|  TELEGRAM : @Alphentra                                           |
//|                                                                  |
//|  --------------------------------------------------------------  |
//|                                                                  |
//|             PROPRIETARY SOFTWARE - ALPHENTRA AI                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Alphentra AI"
#property link      "https://alphentra.app/"
#property version   "1.31"
#property strict
#property description "EMA 5/13 + ATR 14 port | SMART TP/SL ALGO EA | ALPHENTRA AI"

#include <Trade/Trade.mqh>
CTrade trade;


enum ENUM_LOT_MODE { LOT_FIXED=0, LOT_RISK_PERCENT=1 };

input group "=== ORIGINAL PINE SIGNAL ENGINE ==="
input int      InpFastEMA=5;
input int      InpSlowEMA=13;
input int      InpATRPeriod=14;
input double   InpSL_ATR_Multiplier=1.50;
input double   InpTP1_RR=1.0;
input double   InpTP2_RR=2.0;
input double   InpTP3_RR=3.0;
input bool     InpConfirmClosedCandle=true; // safer execution; historical signals use closed candles

input group "=== AUTOMATED TRADING ==="
input bool          InpEnableAlgoTrading=true;
input ENUM_LOT_MODE InpLotMode=LOT_FIXED;
input double        InpFixedLot=0.10;
input double        InpRiskPercent=1.0;
input long          InpMagicNumber=4112026;
input int           InpMaxPositionsPerSymbol=3; // Maximum simultaneous open positions for this EA on this symbol
input int           InpMaxSpreadPoints=0;       // 0 = disabled
input int           InpDeviationPoints=20;
input bool          InpAllowBuy=true;
input bool          InpAllowSell=true;
input bool          InpMoveSLToBreakevenAtTP1=true;
input bool          InpMoveSLToTP1AtTP2=true;

input group "=== ALERTS ==="
input bool     InpPopupAlerts=true;
input bool     InpSoundAlerts=true;
input bool     InpPushNotifications=false;
input bool     InpEmailAlerts=false;
input bool     InpAlertOnTPLevels=true;
input bool     InpAlertOnStopLoss=true;

input group "=== CHART DISPLAY ==="
input bool     InpShowDashboard=true;
input bool     InpShowSignalArrows=true;
input bool     InpShowTradeLevels=true;
input bool     InpShowIndicatorLines=true; // Display Fast EMA and Slow EMA on the price chart


// Internal defaults (kept out of the MT5 Inputs tab).
const int    HISTORICAL_BARS_TO_SCAN = 0;  // 0 = all loaded chart history
const bool   ONE_SIGNAL_PER_BAR      = true;
const string EA_SOUND_FILE           = "alert.wav";
const int    DASHBOARD_X             = 12;
const int    DASHBOARD_Y             = 22;
const int    LEVEL_LINE_BARS         = 15;

// Alphentra palette copied from supplied source: near-black, gold,
// green bullish and red bearish. Product identity is NOT copied.
color C_BG=C'1,0,0';
color C_GOLD=C'255,193,7';
color C_GREEN=C'0,230,118';
color C_RED=C'255,82,82';
color C_MUTED=C'145,150,160';
string PREFIX="ALPH_SMART_TPSL_";

int hFast=INVALID_HANDLE,hSlow=INVALID_HANDLE;
int hATR=INVALID_HANDLE;
string g_atrIndicatorName="";
int g_emaSegments=0;
datetime g_lastBar=0;
datetime g_lastSignalBar=0;
int g_lastDirection=0;
double g_entry=0,g_sl=0,g_tp1=0,g_tp2=0,g_tp3=0;
string g_signal="WAITING",g_status="INITIALIZING";
bool g_tp1Notified=false,g_tp2Notified=false,g_tp3Notified=false,g_slNotified=false;
bool g_historyLoaded=false;
bool g_tp1Hit=false,g_tp2Hit=false,g_tp3Hit=false,g_slHit=false;
int g_latestSignalShift=-1;
datetime g_latestSignalTime=0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpFastEMA<1 || InpSlowEMA<2 || InpATRPeriod<1 ||
      InpSL_ATR_Multiplier<=0 || InpTP1_RR<=0 || InpTP2_RR<=0 || InpTP3_RR<=0 ||
      InpFixedLot<=0 || InpRiskPercent<=0 || InpMaxPositionsPerSymbol<1 ||
      LEVEL_LINE_BARS<1 || HISTORICAL_BARS_TO_SCAN<0)
      return INIT_PARAMETERS_INCORRECT;

   hFast=iMA(_Symbol,_Period,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   hSlow=iMA(_Symbol,_Period,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   hATR=iATR(_Symbol,_Period,InpATRPeriod);
   if(hFast==INVALID_HANDLE || hSlow==INVALID_HANDLE || hATR==INVALID_HANDLE)
   { ReleaseHandles(); return INIT_FAILED; }

   // EMA visuals are drawn directly by this EA using chart objects.
   // No external custom indicator file is required.
   if(InpShowIndicatorLines) DrawEMALines();

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpDeviationPoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   g_status=InpEnableAlgoTrading ? "ALGO ENABLED" : "SIGNALS ONLY";
   ScanHistoricalSignals(); // Reconstruct latest signal only; old arrows are not displayed.
   EventSetTimer(1);
   UpdateDashboard();
   DrawBrandFooter();
   Print("SMART TP/SL ALGO EA initialized | ALPHENTRA AI");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ReleaseHandles();
   ObjectsDeleteAll(0,PREFIX);
   ChartRedraw();
}

void OnTimer()
{
   if(!g_historyLoaded) ScanHistoricalSignals();
   if(InpShowDashboard) UpdateDashboard();
   if(InpShowIndicatorLines) DrawEMALines();
   DrawBrandFooter();
   ManageOpenPosition();
}

void OnTick()
{
   ManageOpenPosition();
   RefreshLatestSignalOutcome();
   datetime bar=iTime(_Symbol,_Period,0);
   if(bar==0) return;
   // Closed-candle mode evaluates once when a new bar opens. Intrabar mode
   // evaluates every tick so it can follow Pine's live-bar crossover behaviour.
   if(InpConfirmClosedCandle)
   {
      if(ONE_SIGNAL_PER_BAR && bar==g_lastBar) return;
      g_lastBar=bar;
      EvaluateSignal();
   }
   else
   {
      EvaluateSignal();
   }
}

// Draw both EMA curves directly as chart-object line segments.
// This keeps all visual code inside the EA; no external .mq5/.ex5 indicator is needed.
void DrawEMALines()
{
   int available=Bars(_Symbol,_Period);
   int count=MathMin(available,500);
   if(count<2 || hFast==INVALID_HANDLE || hSlow==INVALID_HANDLE) return;

   double fast[],slow[];
   ArraySetAsSeries(fast,true);
   ArraySetAsSeries(slow,true);
   int fastCopied=CopyBuffer(hFast,0,0,count,fast);
   int slowCopied=CopyBuffer(hSlow,0,0,count,slow);
   if(fastCopied<2 || slowCopied<2) return;
   count=MathMin(fastCopied,slowCopied);

   for(int shift=0;shift<count-1;shift++)
   {
      datetime newer=iTime(_Symbol,_Period,shift);
      datetime older=iTime(_Symbol,_Period,shift+1);
      if(newer==0 || older==0) continue;

      string fastName=PREFIX+"EMA_FAST_"+IntegerToString(shift);
      if(ObjectFind(0,fastName)<0)
         ObjectCreate(0,fastName,OBJ_TREND,0,older,fast[shift+1],newer,fast[shift]);
      else
      {
         ObjectMove(0,fastName,0,older,fast[shift+1]);
         ObjectMove(0,fastName,1,newer,fast[shift]);
      }
      ObjectSetInteger(0,fastName,OBJPROP_COLOR,clrLimeGreen);
      ObjectSetInteger(0,fastName,OBJPROP_WIDTH,3);
      ObjectSetInteger(0,fastName,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,fastName,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,fastName,OBJPROP_BACK,false);
      ObjectSetInteger(0,fastName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,fastName,OBJPROP_HIDDEN,true);

      string slowName=PREFIX+"EMA_SLOW_"+IntegerToString(shift);
      if(ObjectFind(0,slowName)<0)
         ObjectCreate(0,slowName,OBJ_TREND,0,older,slow[shift+1],newer,slow[shift]);
      else
      {
         ObjectMove(0,slowName,0,older,slow[shift+1]);
         ObjectMove(0,slowName,1,newer,slow[shift]);
      }
      ObjectSetInteger(0,slowName,OBJPROP_COLOR,clrRed);
      ObjectSetInteger(0,slowName,OBJPROP_WIDTH,3);
      ObjectSetInteger(0,slowName,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,slowName,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,slowName,OBJPROP_BACK,false);
      ObjectSetInteger(0,slowName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,slowName,OBJPROP_HIDDEN,true);
   }

   // Remove surplus segments if the available history becomes shorter.
   for(int shift=count-1;shift<g_emaSegments;shift++)
   {
      ObjectDelete(0,PREFIX+"EMA_FAST_"+IntegerToString(shift));
      ObjectDelete(0,PREFIX+"EMA_SLOW_"+IntegerToString(shift));
   }
   g_emaSegments=count-1;
}

void ReleaseHandles()
{
   if(hFast!=INVALID_HANDLE) { IndicatorRelease(hFast); hFast=INVALID_HANDLE; }
   if(hSlow!=INVALID_HANDLE) { IndicatorRelease(hSlow); hSlow=INVALID_HANDLE; }
   if(hATR!=INVALID_HANDLE) { IndicatorRelease(hATR); hATR=INVALID_HANDLE; }
}

bool ReadValue(const int handle,const int buffer,const int shift,double &value)
{
   double a[]; ArraySetAsSeries(a,true);
   if(handle==INVALID_HANDLE || CopyBuffer(handle,buffer,shift,1,a)!=1) return false;
   value=a[0]; return MathIsValidNumber(value);
}

// Pine Script port: ta.ema(close, 5/13), ta.atr(14), crossover/crossunder.
// Scan history to reconstruct the latest signal state; display only that latest marker.
void ScanHistoricalSignals()
{
   int available=Bars(_Symbol,_Period);
   if(available<MathMax(InpFastEMA,InpSlowEMA)+5) return;
   int count=available;
   if(HISTORICAL_BARS_TO_SCAN>0) count=MathMin(count,HISTORICAL_BARS_TO_SCAN+2);
   count=MathMin(count,available);

   double fast[],slow[],atr[];
   ArraySetAsSeries(fast,true); ArraySetAsSeries(slow,true);
   ArraySetAsSeries(atr,true);
   if(CopyBuffer(hFast,0,0,count,fast)<count ||
      CopyBuffer(hSlow,0,0,count,slow)<count ||
      CopyBuffer(hATR,0,0,count,atr)<count)
   { g_status="LOADING HISTORICAL DATA"; return; }

   // Keep the chart clean: remove old BUY/SELL arrows before rebuilding the latest signal.
   DeleteSignalObjects();

   int latestDir=0;
   int latestShift=-1;
   datetime latestTime=0;
   double latestEntry=0,latestSL=0,latestTP1=0,latestTP2=0,latestTP3=0;

   // Walk from oldest closed bar toward the newest closed bar.
   for(int shift=count-2;shift>=1;shift--)
   {
      if(atr[shift]<=0.0) continue;
      double close=iClose(_Symbol,_Period,shift);
      bool crossUp=(fast[shift+1]<=slow[shift+1] && fast[shift]>slow[shift]);
      bool crossDown=(fast[shift+1]>=slow[shift+1] && fast[shift]<slow[shift]);
      bool buy=crossUp;
      bool sell=crossDown;
      if(!buy && !sell) continue;

      int dir=buy ? 1 : -1;
      datetime signalTime=iTime(_Symbol,_Period,shift);
      double entry=close;
      double risk=atr[shift]*InpSL_ATR_Multiplier;
      double sl=dir>0 ? entry-risk : entry+risk;
      double t1=dir>0 ? entry+risk*InpTP1_RR : entry-risk*InpTP1_RR;
      double t2=dir>0 ? entry+risk*InpTP2_RR : entry-risk*InpTP2_RR;
      double t3=dir>0 ? entry+risk*InpTP3_RR : entry-risk*InpTP3_RR;

      latestDir=dir; latestShift=shift; latestTime=signalTime; latestEntry=entry;
      latestSL=sl; latestTP1=t1; latestTP2=t2; latestTP3=t3;
   }

   if(latestDir!=0)
   {
      g_lastDirection=latestDir; g_entry=latestEntry; g_sl=latestSL;
      g_tp1=latestTP1; g_tp2=latestTP2; g_tp3=latestTP3;
      g_signal=latestDir>0 ? "BUY" : "SELL";
      g_status="LATEST HISTORICAL SIGNAL";
      g_lastSignalBar=latestTime;
      g_latestSignalShift=latestShift;
      g_latestSignalTime=latestTime;
      EvaluateHistoricalOutcome(latestDir,latestShift,latestEntry,latestSL,latestTP1,latestTP2,latestTP3);
      if(InpShowSignalArrows)
         DrawSignal(latestDir,latestTime,latestDir>0 ? iLow(_Symbol,_Period,latestShift) : iHigh(_Symbol,_Period,latestShift));
      if(InpShowTradeLevels) DrawLevels(latestDir,latestTime,latestEntry,latestSL,latestTP1,latestTP2,latestTP3);
   }
   else
   {
      g_lastDirection=0; g_entry=0; g_sl=0; g_tp1=0; g_tp2=0; g_tp3=0;
      g_signal="WAITING"; g_status="NO HISTORICAL SIGNAL";
      g_tp1Hit=false; g_tp2Hit=false; g_tp3Hit=false; g_slHit=false; g_latestSignalShift=-1; g_latestSignalTime=0;
   }
   g_historyLoaded=true;
   UpdateDashboard();
   ChartRedraw();
}

// Reconstruct the latest signal outcome from candles printed AFTER its signal bar.
// If SL and a target are both inside one OHLC candle, SL is counted first (conservative).
void EvaluateHistoricalOutcome(const int dir,const int signalShift,const double entry,
                               const double sl,const double tp1,const double tp2,const double tp3)
{
   g_tp1Hit=false; g_tp2Hit=false; g_tp3Hit=false; g_slHit=false;
   if(signalShift<1) { g_status="SIGNAL ACTIVE"; return; }
   // Include shift 0 so the dashboard updates as soon as the live candle touches a target.
   for(int shift=signalShift-1;shift>=0;shift--)
   {
      double hi=iHigh(_Symbol,_Period,shift);
      double lo=iLow(_Symbol,_Period,shift);
      bool stopTouched=(dir>0 ? lo<=sl : hi>=sl);
      bool t1Touched=(dir>0 ? hi>=tp1 : lo<=tp1);
      bool t2Touched=(dir>0 ? hi>=tp2 : lo<=tp2);
      bool t3Touched=(dir>0 ? hi>=tp3 : lo<=tp3);
      // Match supplied Pine Script evaluation order: TP1/2/3 are checked before SL.
      if(t1Touched) g_tp1Hit=true;
      if(t2Touched) { g_tp1Hit=true; g_tp2Hit=true; }
      if(t3Touched) { g_tp1Hit=true; g_tp2Hit=true; g_tp3Hit=true; }
      if(stopTouched)
      {
         g_slHit=true;
         g_status=g_tp2Hit ? "STOPPED AFTER TP2" : (g_tp1Hit ? "STOPPED AFTER TP1" : "STOP LOSS HIT");
         return;
      }
      if(g_tp3Hit) { g_status="ALL TARGETS ACHIEVED"; return; }
   }
   if(g_tp2Hit) g_status="TP2 ACHIEVED";
   else if(g_tp1Hit) g_status="TP1 ACHIEVED";
   else g_status="SIGNAL ACTIVE";
}


// Re-check the newest signal on every tick, including the currently forming candle.
// This keeps TP1/TP2/TP3 status synchronized with live price rather than waiting for bar close.
void RefreshLatestSignalOutcome()
{
   if(g_latestSignalTime<=0 || g_lastDirection==0) return;
   int signalShift=iBarShift(_Symbol,_Period,g_latestSignalTime,true);
   if(signalShift<1) return;
   string previousStatus=g_status;
   bool old1=g_tp1Hit, old2=g_tp2Hit, old3=g_tp3Hit, oldSL=g_slHit;
   EvaluateHistoricalOutcome(g_lastDirection,signalShift,g_entry,g_sl,g_tp1,g_tp2,g_tp3);
   bool outcomeChanged=(previousStatus!=g_status || old1!=g_tp1Hit || old2!=g_tp2Hit || old3!=g_tp3Hit || oldSL!=g_slHit);
   if(outcomeChanged)
   {
      if(InpShowDashboard) UpdateDashboard();
      if(InpShowTradeLevels)
         DrawLevels(g_lastDirection,g_latestSignalTime,g_entry,g_sl,g_tp1,g_tp2,g_tp3);
   }
}

void EvaluateSignal()
{
   // Pine ta.crossover/ta.crossunder: current EMA compared with prior EMA.
   // Closed-bar mode evaluates shift 1 and is the default for stable, non-repainting execution.
   int shift=InpConfirmClosedCandle ? 1 : 0;
   double f0,f1,s0,s1,atr;
   if(!ReadValue(hFast,0,shift,f0) || !ReadValue(hFast,0,shift+1,f1) ||
      !ReadValue(hSlow,0,shift,s0) || !ReadValue(hSlow,0,shift+1,s1) ||
      !ReadValue(hATR,0,shift,atr))
   { g_status="WAITING FOR HISTORY"; return; }
   if(atr<=0.0) return;
   bool buy=(f1<=s1 && f0>s0);
   bool sell=(f1>=s1 && f0<s0);
   if(!buy && !sell) return;

   datetime signalTime=iTime(_Symbol,_Period,shift);
   if(signalTime==0 || signalTime==g_lastSignalBar) return;
   g_lastSignalBar=signalTime;
   g_latestSignalTime=signalTime;
   g_latestSignalShift=shift;
   int dir=buy ? 1 : -1;
   // Faithful Pine formula: signal candle close is the theoretical entry.
   double entry=iClose(_Symbol,_Period,shift);
   double risk=atr*InpSL_ATR_Multiplier;
   double sl=dir>0 ? entry-risk : entry+risk;
   double t1=dir>0 ? entry+risk*InpTP1_RR : entry-risk*InpTP1_RR;
   double t2=dir>0 ? entry+risk*InpTP2_RR : entry-risk*InpTP2_RR;
   double t3=dir>0 ? entry+risk*InpTP3_RR : entry-risk*InpTP3_RR;
   g_lastDirection=dir; g_entry=entry; g_sl=sl; g_tp1=t1; g_tp2=t2; g_tp3=t3;
   g_signal=dir>0 ? "BUY" : "SELL";
   g_status="SIGNAL CONFIRMED";
   g_tp1Notified=false; g_tp2Notified=false; g_tp3Notified=false; g_slNotified=false;
   g_tp1Hit=false; g_tp2Hit=false; g_tp3Hit=false; g_slHit=false;

   // Retain only the newest signal marker; remove previous BUY/SELL markers.
   DeleteSignalObjects();
   if(InpShowSignalArrows) DrawSignal(dir,signalTime,dir>0 ? iLow(_Symbol,_Period,shift) : iHigh(_Symbol,_Period,shift));
   if(InpShowTradeLevels) DrawLevels(dir,signalTime,entry,sl,t1,t2,t3);
   SendAlert(g_signal+" SIGNAL | "+_Symbol+" | "+EnumToString(_Period)+
             " | Entry "+Price(entry)+" | SL "+Price(sl)+
             " | TP1 "+Price(t1)+" | TP2 "+Price(t2)+" | TP3 "+Price(t3));

   // Only a newly confirmed bar signal reaches execution. Historical scan never calls this.
   if(InpEnableAlgoTrading && ((dir>0 && InpAllowBuy) || (dir<0 && InpAllowSell)))
      ExecuteSignal(dir,sl,t3);
}

void ExecuteSignal(const int dir,const double sl,const double tp)
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   { g_status="TRADING PERMISSION BLOCKED"; return; }
   if(InpMaxSpreadPoints>0)
   {
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK),bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if((ask-bid)/_Point>InpMaxSpreadPoints) { g_status="SPREAD FILTER"; return; }
   }
   if(CountOurPositions()>=InpMaxPositionsPerSymbol) { g_status="POSITION LIMIT"; return; }

   double price=dir>0 ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double stopDistance=MathAbs(price-sl);
   if(stopDistance<=0) return;
   double lots=InpLotMode==LOT_FIXED ? InpFixedLot : CalculateRiskLot(stopDistance);
   lots=NormalizeVolume(lots);
   if(lots<=0) { g_status="INVALID LOT SIZE"; return; }

   bool ok=false;
   if(dir>0) ok=trade.Buy(lots,_Symbol,0.0,NormalizePrice(sl),NormalizePrice(tp),"SMART TP/SL BUY");
   else      ok=trade.Sell(lots,_Symbol,0.0,NormalizePrice(sl),NormalizePrice(tp),"SMART TP/SL SELL");
   if(ok && TradeRetcodeOK()) g_status="ORDER PLACED";
   else { g_status="ORDER FAILED: "+trade.ResultRetcodeDescription(); Print(g_status); }
}

int CountOurPositions()
{
   int count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagicNumber) count++;
   }
   return count;
}

double CalculateRiskLot(const double stopDistance)
{
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney=equity*InpRiskPercent/100.0;
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickSize<=0 || tickValue<=0 || stopDistance<=0) return 0;
   return riskMoney/(stopDistance/tickSize*tickValue);
}

double NormalizeVolume(double lots)
{
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(step<=0) return 0;
   lots=MathFloor(lots/step+1e-8)*step;
   lots=MathMax(vmin,MathMin(vmax,lots));
   int digits=2;
   if(step<0.01) digits=3;
   if(step<0.001) digits=4;
   return NormalizeDouble(lots,digits);
}

double NormalizePrice(double p) { return NormalizeDouble(p,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)); }
string Price(double p) { return DoubleToString(p,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)); }
bool TradeRetcodeOK()
{
   uint r=trade.ResultRetcode();
   return r==TRADE_RETCODE_DONE || r==TRADE_RETCODE_PLACED || r==TRADE_RETCODE_DONE_PARTIAL;
}

void ManageOpenPosition()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID),ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double current=type==POSITION_TYPE_BUY ? bid : ask;
      double initialRisk=(tp>0 ? MathAbs(tp-open)/InpTP3_RR : 0.0);
      if(initialRisk<=0) continue;
      double one=type==POSITION_TYPE_BUY ? open+initialRisk*InpTP1_RR : open-initialRisk*InpTP1_RR;
      double two=type==POSITION_TYPE_BUY ? open+initialRisk*InpTP2_RR : open-initialRisk*InpTP2_RR;
      double three=type==POSITION_TYPE_BUY ? open+initialRisk*InpTP3_RR : open-initialRisk*InpTP3_RR;
      bool hit1=type==POSITION_TYPE_BUY ? current>=one : current<=one;
      bool hit2=type==POSITION_TYPE_BUY ? current>=two : current<=two;
      bool hit3=type==POSITION_TYPE_BUY ? current>=three : current<=three;
      if(hit1) g_tp1Hit=true;
      if(hit2) { g_tp1Hit=true; g_tp2Hit=true; }
      if(hit3)
      {
         g_tp1Hit=true; g_tp2Hit=true; g_tp3Hit=true;
         g_status="ALL TARGETS ACHIEVED";
      }
      else if(hit2) g_status="TP2 ACHIEVED";
      else if(hit1) g_status="TP1 ACHIEVED";
      if(InpAlertOnTPLevels && hit1 && !g_tp1Notified) { SendAlert("TP1 REACHED | "+_Symbol+" | "+Price(one)); g_tp1Notified=true; }
      if(InpAlertOnTPLevels && hit2 && !g_tp2Notified) { SendAlert("TP2 REACHED | "+_Symbol+" | "+Price(two)); g_tp2Notified=true; }
      if(InpAlertOnTPLevels && hit3 && !g_tp3Notified) { SendAlert("TP3 REACHED | "+_Symbol+" | "+Price(three)); g_tp3Notified=true; }
      if(InpMoveSLToBreakevenAtTP1 && hit1)
      {
         double newSL=open;
         bool improves=(type==POSITION_TYPE_BUY ? (sl==0 || newSL>sl) : (sl==0 || newSL<sl));
         if(improves) trade.PositionModify(ticket,NormalizePrice(newSL),tp);
      }
      if(InpMoveSLToTP1AtTP2 && hit2)
      {
         double newSL=one;
         bool improves=(type==POSITION_TYPE_BUY ? newSL>sl : (sl==0 || newSL<sl));
         if(improves) trade.PositionModify(ticket,NormalizePrice(newSL),tp);
      }
   }
}


// Detect broker-executed stop-loss exits and send the configured SL alert.
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(!InpAlertOnStopLoss || trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;

   long dealMagic=HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
   string dealSymbol=HistoryDealGetString(trans.deal,DEAL_SYMBOL);
   long dealEntry=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   long dealReason=HistoryDealGetInteger(trans.deal,DEAL_REASON);

   if(dealMagic!=InpMagicNumber || dealSymbol!=_Symbol)
      return;
   if((dealEntry==DEAL_ENTRY_OUT || dealEntry==DEAL_ENTRY_OUT_BY) && dealReason==DEAL_REASON_SL)
      SendAlert("STOP LOSS EXECUTED | "+dealSymbol+" | Deal "+(string)trans.deal);
}

void SendAlert(const string message)
{
   Print(message);
   if(InpPopupAlerts) Alert(message);
   if(InpSoundAlerts && StringLen(EA_SOUND_FILE)>0) PlaySound(EA_SOUND_FILE);
   if(InpPushNotifications) SendNotification(message);
   if(InpEmailAlerts) SendMail("SMART TP/SL ALGO EA",message);
}

void DeleteSignalObjects()
{
   // Delete only this EA's signal arrows and their BUY/SELL text labels.
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--)
   {
      string name=ObjectName(0,i,0,-1);
      if(StringFind(name,PREFIX+"SIGNAL_")==0)
         ObjectDelete(0,name);
   }
}

void DrawSignal(const int dir,const datetime when,const double price)
{
   string id=PREFIX+"SIGNAL_"+(string)when;

   if(ObjectFind(0,id)>=0)
      return;

   // Draw signal arrow
   ObjectCreate(0,id,OBJ_ARROW,0,when,price);

   ObjectSetInteger(0,id,OBJPROP_ARROWCODE,dir>0 ? 233 : 234);
   ObjectSetInteger(0,id,OBJPROP_COLOR,dir>0 ? C_GREEN : C_RED);
   ObjectSetInteger(0,id,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,id,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,id,OBJPROP_HIDDEN,true);

   // Dynamic signal label spacing based on ATR
   double atrValue[];
   ArraySetAsSeries(atrValue,true);

   double textOffset=10.0*_Point;

   if(hATR!=INVALID_HANDLE)
   {
      if(CopyBuffer(hATR,0,0,1,atrValue)>0 && atrValue[0]>0)
         textOffset=atrValue[0]*0.55;
   }

   // BUY below arrow; SELL above arrow
   double labelPrice=dir>0
                     ? price-textOffset
                     : price+textOffset;

   string label=id+"_TXT";

   ObjectCreate(0,label,OBJ_TEXT,0,when,labelPrice);

   ObjectSetString(0,label,OBJPROP_TEXT,dir>0 ? " BUY" : " SELL");
   ObjectSetInteger(0,label,OBJPROP_COLOR,dir>0 ? C_GREEN : C_RED);
   ObjectSetInteger(0,label,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,label,OBJPROP_FONT,"Arial Bold");

   ObjectSetInteger(0,label,OBJPROP_ANCHOR,
                    dir>0 ? ANCHOR_UPPER : ANCHOR_LOWER);

   ObjectSetInteger(0,label,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,label,OBJPROP_HIDDEN,true);
}

void DrawLevels(const int dir,const datetime signalTime,const double entry,const double sl,
                const double t1,const double t2,const double t3)
{
   // Match the Pine source: risk/reward objects begin on the actual signal
   // candle and extend 15 bars forward, not from the current chart candle.
   datetime t0=signalTime;
   datetime t1x=t0+(datetime)(PeriodSeconds(_Period)*LEVEL_LINE_BARS);

   // Filled risk/reward zones: red between Entry and SL, green between
   // Entry and TP3. Draw these first and behind the candles/level lines.
   double redTop=MathMax(entry,sl), redBottom=MathMin(entry,sl);
   double greenTop=MathMax(entry,t3), greenBottom=MathMin(entry,t3);
   DrawZone("RISK_ZONE",t0,redTop,t1x,redBottom,C'105,28,35');
   DrawZone("REWARD_ZONE",t0,greenTop,t1x,greenBottom,C'0,78,42');

   DrawLevel(dir,"ENTRY",entry,t0,t1x,C'255,174,0',"ENTRY",STYLE_SOLID,2);
   // Keep the SL line and its right-side price, but omit the extra text caption.
   DrawLevel(dir,"SL",sl,t0,t1x,C'255,75,75',"",STYLE_DASH,2);
   DrawLevel(dir,"TP1",t1,t0,t1x,C'255,230,0',g_tp1Hit ? "TP1 - 1:1 HIT" : "TP1 - 1:1",STYLE_DASH,2);
   DrawLevel(dir,"TP2",t2,t0,t1x,C'0,174,255',g_tp2Hit ? "TP2 - 1:2 HIT" : "TP2 - 1:2",STYLE_DASH,2);
   DrawLevel(dir,"TP3",t3,t0,t1x,C'0,230,70',g_tp3Hit ? "TP3 - 1:3 HIT" : "TP3 - 1:3",STYLE_SOLID,3);
}

void DrawZone(const string tag,const datetime a,const double top,
              const datetime b,const double bottom,const color zoneColor)
{
   string id=PREFIX+tag;
   if(ObjectFind(0,id)<0)
      ObjectCreate(0,id,OBJ_RECTANGLE,0,a,top,b,bottom);
   else
   {
      ObjectMove(0,id,0,a,top);
      ObjectMove(0,id,1,b,bottom);
   }
   ObjectSetInteger(0,id,OBJPROP_COLOR,zoneColor);
   ObjectSetInteger(0,id,OBJPROP_FILL,true);
   ObjectSetInteger(0,id,OBJPROP_BACK,true);
   ObjectSetInteger(0,id,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,id,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,id,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,id,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,id,OBJPROP_HIDDEN,true);
}

void DrawLevel(const int direction,
               const string tag,
               const double price,
               const datetime a,
               const datetime b,
               const color clr,
               const string caption,
               const ENUM_LINE_STYLE style,
               const int thickness)
{
   string line=PREFIX+"LEVEL_"+tag;

   // Draw horizontal level
   if(ObjectFind(0,line)<0)
      ObjectCreate(0,line,OBJ_TREND,0,a,price,b,price);
   else
   {
      ObjectMove(0,line,0,a,price);
      ObjectMove(0,line,1,b,price);
   }

   ObjectSetInteger(0,line,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,line,OBJPROP_STYLE,style);
   ObjectSetInteger(0,line,OBJPROP_WIDTH,thickness);
   ObjectSetInteger(0,line,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,line,OBJPROP_BACK,false);
   ObjectSetInteger(0,line,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,line,OBJPROP_HIDDEN,true);

   // ALL trade-level captions stay on the LEFT side for BOTH BUY and SELL.
   // Anchor RIGHT makes the caption text extend leftwards from its anchor.
   string captionName=line+"_CAPTION";

   if(caption!="")
   {
      datetime captionTime=a-(datetime)PeriodSeconds(_Period);

      if(ObjectFind(0,captionName)<0)
         ObjectCreate(0,captionName,OBJ_TEXT,0,captionTime,price);
      else
         ObjectMove(0,captionName,0,captionTime,price);

      ObjectSetString(0,captionName,OBJPROP_TEXT,caption);
      ObjectSetString(0,captionName,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,captionName,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,captionName,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(0,captionName,OBJPROP_ANCHOR,ANCHOR_RIGHT);
      ObjectSetInteger(0,captionName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,captionName,OBJPROP_HIDDEN,true);
   }
   else
   {
      ObjectDelete(0,captionName);
   }

   // Right-side price marker
   string priceName=line+"_PRICE";

   if(ObjectFind(0,priceName)<0)
      ObjectCreate(0,priceName,OBJ_TEXT,0,b,price);
   else
      ObjectMove(0,priceName,0,b,price);

   ObjectSetString(0,priceName,OBJPROP_TEXT,"  "+Price(price));
   ObjectSetString(0,priceName,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,priceName,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,priceName,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,priceName,OBJPROP_ANCHOR,ANCHOR_LEFT);
   ObjectSetInteger(0,priceName,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,priceName,OBJPROP_HIDDEN,true);
}
// Measure text using the same font settings used by the dashboard labels.
void MeasureDashboardText(const string value,const int fontSize,const string font,
                          int &width,int &height)
{
   uint measuredWidth=0,measuredHeight=0;
   if(TextGetSize(value,measuredWidth,measuredHeight))
   {
      width=(int)measuredWidth;
      height=(int)measuredHeight;
   }
   else
   {
      // Conservative fallback if the terminal cannot measure a font.
      width=(int)(StringLen(value)*fontSize*0.70);
      height=fontSize+5;
   }
}

void DashboardDivider(const string id,const int x,const int y,const int width)
{
   string name=PREFIX+"DIVIDER_"+id;
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,1);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,C_GOLD);
   ObjectSetInteger(0,name,OBJPROP_COLOR,C_GOLD);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void UpdateDashboard()
{
   const int leftPad=12,rightPad=12,topPad=9,bottomPad=9;
   const int rowGap=5,sectionGap=7;
   string title="SMART TP/SL ALGO EA";
   string sub=_Symbol+"  |  "+EnumToString(_Period);
   string signal="SIGNAL: "+g_signal;
   string entry="ENTRY: "+(g_entry>0 ? Price(g_entry) : "--");
   string stop="STOP LOSS: "+(g_sl>0 ? Price(g_sl) : "--");
   string tp1="TP1: "+(g_tp1>0 ? Price(g_tp1) : "--")+"  "+(g_tp1Hit ? "HIT" : "PENDING");
   string tp2="TP2: "+(g_tp2>0 ? Price(g_tp2) : "--")+"  "+(g_tp2Hit ? "HIT" : "PENDING");
   string tp3="TP3: "+(g_tp3>0 ? Price(g_tp3) : "--")+"  "+(g_tp3Hit ? "HIT" : "PENDING");
   string status="STATUS: "+g_status;
   string tagline="TRADE BEYOND LIMITS";

   int widths[9],heights[9];
   MeasureDashboardText(title,12,"Arial Bold",widths[0],heights[0]);
   MeasureDashboardText(sub,10,"Arial",widths[1],heights[1]);
   MeasureDashboardText(signal,12,"Arial Bold",widths[2],heights[2]);
   MeasureDashboardText(entry,11,"Arial",widths[3],heights[3]);
   MeasureDashboardText(stop,11,"Arial",widths[4],heights[4]);
   MeasureDashboardText(tp1,10,"Arial",widths[5],heights[5]);
   MeasureDashboardText(tp2,10,"Arial",widths[6],heights[6]);
   MeasureDashboardText(tp3,10,"Arial",widths[7],heights[7]);
   MeasureDashboardText(status,10,"Arial Bold",widths[8],heights[8]);
   int taglineWidth=0,taglineHeight=0;
   MeasureDashboardText(tagline,9,"Arial Bold",taglineWidth,taglineHeight);

   int contentWidth=taglineWidth;
   for(int i=0;i<ArraySize(widths);i++)
      if(widths[i]>contentWidth) contentWidth=widths[i];
   int panelWidth=contentWidth+leftPad+rightPad;

   int y=topPad;
   int titleY=y; y+=heights[0]+rowGap;
   int subY=y; y+=heights[1]+sectionGap;
   int divider1Y=y; y+=sectionGap+2;
   int signalY=y; y+=heights[2]+rowGap;
   int entryY=y; y+=heights[3]+rowGap;
   int stopY=y; y+=heights[4]+rowGap;
   int tp1Y=y; y+=heights[5]+rowGap;
   int tp2Y=y; y+=heights[6]+rowGap;
   int tp3Y=y; y+=heights[7]+rowGap;
   int statusY=y; y+=heights[8]+sectionGap;
   int divider2Y=y; y+=sectionGap+2;
   int taglineY=y; y+=taglineHeight+bottomPad;
   int panelHeight=y;

   string bg=PREFIX+"PANEL";
   if(ObjectFind(0,bg)<0) ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,DASHBOARD_X);
   ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,DASHBOARD_Y);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,panelWidth);
   ObjectSetInteger(0,bg,OBJPROP_YSIZE,panelHeight);
   ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C_BG);
   ObjectSetInteger(0,bg,OBJPROP_COLOR,C_GOLD);
   ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,bg,OBJPROP_BACK,false);
   ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);

   Label("TITLE",DASHBOARD_X+leftPad,DASHBOARD_Y+titleY,title,C_GOLD,12,"Arial Bold");
   Label("SUB",DASHBOARD_X+leftPad,DASHBOARD_Y+subY,sub,C_MUTED,10,"Arial");
   DashboardDivider("TOP",DASHBOARD_X+leftPad,DASHBOARD_Y+divider1Y,panelWidth-leftPad-rightPad);
   color sigColor=g_lastDirection>0 ? C_GREEN : (g_lastDirection<0 ? C_RED : C_MUTED);
   Label("SIGNAL",DASHBOARD_X+leftPad+2,DASHBOARD_Y+signalY,signal,sigColor,12,"Arial Bold");
   Label("ENTRY",DASHBOARD_X+leftPad+2,DASHBOARD_Y+entryY,entry,C_GOLD,11,"Arial");
   Label("SL",DASHBOARD_X+leftPad+2,DASHBOARD_Y+stopY,stop,C_RED,11,"Arial");
   Label("TPS",DASHBOARD_X+leftPad+2,DASHBOARD_Y+tp1Y,tp1,g_tp1Hit ? C_GREEN : C_MUTED,10,"Arial");
   Label("TP2",DASHBOARD_X+leftPad+2,DASHBOARD_Y+tp2Y,tp2,g_tp2Hit ? C_GREEN : C_MUTED,10,"Arial");
   Label("TP3",DASHBOARD_X+leftPad+2,DASHBOARD_Y+tp3Y,tp3,g_tp3Hit ? C_GREEN : C_MUTED,10,"Arial");
   Label("STATUS",DASHBOARD_X+leftPad+2,DASHBOARD_Y+statusY,status,C_GOLD,10,"Arial Bold");
   DashboardDivider("BOTTOM",DASHBOARD_X+leftPad,DASHBOARD_Y+divider2Y,panelWidth-leftPad-rightPad);
   Label("TAGLINE",DASHBOARD_X+leftPad+2,DASHBOARD_Y+taglineY,tagline,C_GOLD,9,"Arial Bold");
}

void Label(const string id,const int x,const int y,const string txt,const color clr,const int size,const string font)
{
   string n=PREFIX+"LBL_"+id;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,n,OBJPROP_FONT,font);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);
}

// Make the Alphentra footer interactive. Clicking either the badge text or
// its background displays the official Telegram channel in an MT5 alert.
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_CLICK &&
      (sparam==PREFIX+"BRAND_TX" || sparam==PREFIX+"BRAND_BG"))
   {
      // Display a multiline native MT5 message box; no DLL is required.
      // The Telegram address can be copied into a browser.
      MessageBox("ALPHENTRA AI | TRADE BEYOND LIMITS.\n"
                 "Join our official Telegram channel:\n"
                 "https://t.me/Alphentra",
                 "ALPHENTRA AI",
                 MB_OK | MB_ICONINFORMATION);

      // Clear the selected state so the badge remains easy to click again.
      ObjectSetInteger(0,sparam,OBJPROP_SELECTED,false);
      ChartRedraw(0);
   }
}

void DrawBrandFooter()
{
   long w=0,h=0;

   if(!ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0,w) ||
      !ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0,h))
      return;

   string text="Telegram - @Alphentra";
   string font="Arial Bold";

   int fontSize=11;
   int paddingX=18;
   int paddingY=9;

   // Automatically measure text dimensions
   uint textWidth=0,textHeight=0;

   if(!TextGetSize(text,textWidth,textHeight))
   {
      textWidth=(uint)(StringLen(text)*fontSize*0.75);
      textHeight=(uint)(fontSize+5);
   }

   // Dynamic box dimensions
   int fw=(int)textWidth+(paddingX*2);
   int fh=(int)textHeight+(paddingY*2);

   // Position at bottom-right
   int x=(int)w-14-fw;
   int y=(int)h-20-fh;

   if(x<0) x=0;
   if(y<0) y=0;

   string bg=PREFIX+"BRAND_BG";
   string tx=PREFIX+"BRAND_TX";

   // Background box
   if(ObjectFind(0,bg)<0)
      ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,fw);
   ObjectSetInteger(0,bg,OBJPROP_YSIZE,fh);
   ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C_BG);
   ObjectSetInteger(0,bg,OBJPROP_COLOR,C_GOLD);
   ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,bg,OBJPROP_ZORDER,999);
   ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);

   // Footer text
   if(ObjectFind(0,tx)<0)
      ObjectCreate(0,tx,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,tx,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,tx,OBJPROP_XDISTANCE,x+paddingX);
   ObjectSetInteger(0,tx,OBJPROP_YDISTANCE,y+paddingY);
   ObjectSetInteger(0,tx,OBJPROP_COLOR,C_GOLD);
   ObjectSetInteger(0,tx,OBJPROP_FONTSIZE,fontSize);
   ObjectSetString(0,tx,OBJPROP_FONT,font);
   ObjectSetString(0,tx,OBJPROP_TEXT,text);
   ObjectSetInteger(0,tx,OBJPROP_ZORDER,1000);
   ObjectSetInteger(0,tx,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,tx,OBJPROP_HIDDEN,true);
}
//+------------------------------------------------------------------+