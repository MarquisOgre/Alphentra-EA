//+------------------------------------------------------------------+
//|                                                                  |
//|                                                                  |
//|                                                                  |
//|                    A L P H E N T R A   A I                       |
//|                                                                  |
//|                     TRADE BEYOND LIMITS.                         |
//|                                                                  |
//|                         HFT-CaR                                  |
//|  --------------------------------------------------------------  |
//|                                                                  |
//|  PRODUCT  : HFT-CaR                                              |
//|  DEVELOPER: ALPHENTRA AI                                         |
//|  ENGINE   : HFT-CaR TRADING ENGINE                               |
//|                                                                  |
//|  FEATURES  : EMA/RSI SIGNALS, LIMIT ENTRIES, CaR RECOVERY        |
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
#property version   "1.1"
#property strict
#property description "Alphentra HFT-CaR integrated with dynamic dashboard"

input group "=== ALPHENTRA DISPLAY ==="
input bool InpShowDashboard = true;
input bool InpShowBrandFooter = true;
input int  InpDashboardX = 12;
input int  InpDashboardY = 22;

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

CTrade trade;
CPositionInfo posInfo;
COrderInfo orderInfo;
CSymbolInfo symInfo;
CAccountInfo accInfo;

enum ENUM_CAR_STATE { CAR_IDLE, CAR_RECOVERING, CAR_COOLDOWN };

input group "=== CaR ENGINE ==="
input double   InpInitialLot       = 0.01;
input double   InpMultiplier       = 1.8;
input double   InpDistancePoints   = 80;
input bool     InpUseATRDistance   = true;
input double   InpATRMultDist      = 1.2;
input double   InpTPBufferPoints   = 10;
input int      InpMaxSteps         = 7;
input int      InpCooldownSec      = 8;
input bool     InpRequireProfit    = false;
input group "=== LIMIT ENTRY (Fixed) ==="
input bool     InpUseLimitOrders   = true;      // true = use Limit, false = market
input int      InpLimitOffsetPips  = 15;        // Offset in pips (increase if still rejected)
input int      InpLimitMaxBars     = 12;        // Auto-cancel pending after X bars
input bool     InpUseOddEvenBias   = true;

input group "=== SIGNAL ==="
input int      InpFastEMA          = 8;
input int      InpSlowEMA          = 21;
input int      InpRSIPeriod        = 14;
input double   InpRSIBuyMax        = 70;
input double   InpRSISellMin       = 30;
input ENUM_TIMEFRAMES InpTF        = PERIOD_M1;

input group "=== EMA LINE STYLE ==="
input bool   InpShowFastEMA       = true;
input bool   InpShowSlowEMA       = true;
input color  InpFastEMAColor      = clrDodgerBlue;
input color  InpSlowEMAColor      = clrOrangeRed;
input int    InpFastEMAWidth      = 2;
input int    InpSlowEMAWidth      = 2;
input int    InpEMADisplayBars    = 250; // number of chart-timeframe bars to draw

input group "=== RISK ==="
input double   InpMaxDailyLossPct  = 5.0;
input double   InpMaxDrawdownPct   = 12.0;
input double   InpMaxSpreadPoints  = 50;
input ulong    InpMagic            = 20261007;
input int      InpSlippage         = 30;
input bool     InpDebug            = true;

int handleFast=INVALID_HANDLE, handleSlow=INVALID_HANDLE;
int handleRSI=INVALID_HANDLE, handleATR=INVALID_HANDLE;
// Separate chart-timeframe handles are used only for the styled EMA drawings.
int handleVisualFast=INVALID_HANDLE, handleVisualSlow=INVALID_HANDLE;
datetime g_lastEMADrawBar=0;
ENUM_CAR_STATE g_carState = CAR_IDLE;
double g_carDebt = 0, g_carLot = 0;
int g_carStep = 0, g_carDir = 0;
datetime g_carTime = 0;
bool g_lastProfit = true;
double pipValue = 0;
int g_digits = 0;
double dailyStartEq = 0, peakEquity = 0, startEquity = 0;
bool tradingEnabled = true;
string statusText = "Ready", lastSignal = "-";
int lastSignalDir = 0;
datetime pendingPlaceTime = 0;


const color C_BG    = C'5,5,5';
const color C_GOLD  = C'255,193,7';
const color C_GREEN = C'0,220,100';
const color C_RED   = C'255,75,75';
const color C_MUTED = C'165,165,165';
const color C_WHITE = C'235,235,235';
const color C_PANEL = C'8,8,8';

const string PREFIX = "ALPHENTRA_HFT_CAR_";

// Measure displayed text for content-based sizing.
// Match the working SMART TP/SL ALGO EA dashboard text measurement.
// Keep this implementation identical to the proven dashboard approach.
void MeasureText(const string text,const int fontSize,const string font,
                 int &width,int &height)
{
   uint tw=0,th=0;
   if(TextGetSize(text,tw,th))
   {
      width=(int)tw;
      height=(int)th;
   }
   else
   {
      width=(int)(StringLen(text)*fontSize*0.70);
      height=fontSize+5;
   }
}

void SetDashboardLabel(const string id,const int x,const int y,
                       const string text,const color clr,
                       const int fontSize,const string font)
{
   string name=PREFIX+"DASH_"+id;
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize);
   ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,1001);
}

void SetDashboardDivider(const string id,
                         const int x,
                         const int y,
                         const int width)
{
   string name=PREFIX+"DASH_DIV_"+id;

   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);

   // Width is supplied by the dashboard's measured inner width.
   // Height remains a thin one-pixel divider.
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,1);

   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,C_GOLD);
   ObjectSetInteger(0,name,OBJPROP_COLOR,C_GOLD);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,1000);
}

// DYNAMIC DASHBOARD: width follows the longest text; height follows rows.
void UpdateDynamicDashboard()
{
   if(!InpShowDashboard)
      return;

   string title="HFT-CaR";
   string subtitle=_Symbol+"  |  "+EnumToString(_Period);

   string rows[7];
   color rowColors[7];
   int rowFonts[7];

   string carStateText=(g_carState==CAR_RECOVERING ? "RECOVERING" :
                        (g_carState==CAR_COOLDOWN ? "COOLDOWN" : "IDLE"));
   rows[0]="SIGNAL: "+lastSignal;
   rows[1]="CYCLE: "+carStateText;
   rows[2]="STEP: "+IntegerToString(g_carStep)+" / "+IntegerToString(InpMaxSteps);
   rows[3]="RECOVERY DEBT: "+DoubleToString(g_carDebt,2);
   rows[4]="NEXT LOT: "+DoubleToString(g_carLot>0 ? g_carLot : InpInitialLot,2);
   rows[5]="EQUITY: "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2);
   rows[6]="STATUS: "+statusText;

   rowColors[0]=(lastSignal=="BUY" ? C_GREEN :
                 (lastSignal=="SELL" ? C_RED : C_GOLD));
   rowColors[1]=C_GOLD;
   rowColors[2]=C_RED;
   rowColors[3]=C_GOLD;
   rowColors[4]=C'0,174,255';
   rowColors[5]=C_GREEN;
   rowColors[6]=C_GOLD;

   rowFonts[0]=12;
   rowFonts[1]=11;
   rowFonts[2]=11;
   rowFonts[3]=10;
   rowFonts[4]=10;
   rowFonts[5]=10;
   rowFonts[6]=10;

   const int padL=12,padR=12,padTop=9,padBottom=9;
   const int rowGap=5,sectionGap=7;

   int titleW=0,titleH=0,subW=0,subH=0;
   MeasureText(title,12,"Arial Bold",titleW,titleH);
   MeasureText(subtitle,10,"Arial",subW,subH);

   int widths[7],heights[7];
   int contentWidth=(int)MathMax(titleW,subW);

   for(int i=0;i<7;i++)
   {
      string font=(i==0 || i==6) ? "Arial Bold" : "Arial";
      MeasureText(rows[i],rowFonts[i],font,widths[i],heights[i]);
      if(widths[i]>contentWidth)
         contentWidth=widths[i];
   }

   string tagline="TRADE BEYOND LIMITS.";
   int tagW=0,tagH=0;
   MeasureText(tagline,9,"Arial Bold",tagW,tagH);
   if(tagW>contentWidth)
      contentWidth=tagW;

   int panelWidth=contentWidth+padL+padR;

   int y=padTop;
   int titleY=y;
   y+=titleH+5;
   int subtitleY=y;
   y+=subH+sectionGap;
   int topDividerY=y;
   y+=sectionGap+2;

   int rowY[7];
   for(int i=0;i<7;i++)
   {
      rowY[i]=y;
      y+=heights[i]+rowGap;
      if(i==0) y+=2;
   }

   int bottomDividerY=y;
   y+=sectionGap+2;
   int taglineY=y;
   y+=tagH+padBottom;
   int panelHeight=y;

   string panel=PREFIX+"DASH_PANEL";
   if(ObjectFind(0,panel)<0)
      ObjectCreate(0,panel,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,panel,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,panel,OBJPROP_XDISTANCE,InpDashboardX);
   ObjectSetInteger(0,panel,OBJPROP_YDISTANCE,InpDashboardY);
   ObjectSetInteger(0,panel,OBJPROP_XSIZE,panelWidth);
   ObjectSetInteger(0,panel,OBJPROP_YSIZE,panelHeight);
   ObjectSetInteger(0,panel,OBJPROP_BGCOLOR,C_PANEL);
   ObjectSetInteger(0,panel,OBJPROP_COLOR,C_GOLD);
   ObjectSetInteger(0,panel,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,panel,OBJPROP_BACK,false);
   ObjectSetInteger(0,panel,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,panel,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,panel,OBJPROP_ZORDER,999);

   SetDashboardLabel("TITLE",InpDashboardX+padL,InpDashboardY+titleY,
                     title,C_GOLD,12,"Arial Bold");
   SetDashboardLabel("SUBTITLE",InpDashboardX+padL,InpDashboardY+subtitleY,
                     subtitle,C_MUTED,10,"Arial");
   SetDashboardDivider("TOP",InpDashboardX+padL,InpDashboardY+topDividerY,
                       panelWidth-padL-padR);

   for(int i=0;i<7;i++)
   {
      string id="ROW_"+IntegerToString(i);
      string font=(i==0 || i==6) ? "Arial Bold" : "Arial";
      SetDashboardLabel(id,InpDashboardX+padL+2,InpDashboardY+rowY[i],
                        rows[i],rowColors[i],rowFonts[i],font);
   }

   SetDashboardDivider("BOTTOM",InpDashboardX+padL,
                       InpDashboardY+bottomDividerY,panelWidth-padL-padR);
   SetDashboardLabel("TAGLINE",InpDashboardX+padL+2,InpDashboardY+taglineY,
                     tagline,C_GOLD,9,"Arial Bold");
}

// DYNAMIC FOOTER: box dimensions are measured from @Alphentra.
void UpdateBrandFooter()
{
   if(!InpShowBrandFooter)
      return;

   long cw=0,ch=0;
   if(!ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0,cw) ||
      !ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0,ch))
      return;

   string footer="Telegram - @Alphentra";
   int fs=11,padX=18,padY=9;
   uint tw=0,th=0;

   if(!TextGetSize(footer,tw,th))
   {
      tw=(uint)(StringLen(footer)*fs*0.75);
      th=(uint)(fs+5);
   }

   int bw=(int)tw+padX*2;
   int bh=(int)th+padY*2;
   int x=(int)cw-14-bw;
   int y=(int)ch-20-bh;
   if(x<0) x=0;
   if(y<0) y=0;

   string bg=PREFIX+"BRAND_BG";
   string tx=PREFIX+"BRAND_TX";

   if(ObjectFind(0,bg)<0)
      ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,bw);
   ObjectSetInteger(0,bg,OBJPROP_YSIZE,bh);
   ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C_BG);
   ObjectSetInteger(0,bg,OBJPROP_COLOR,C_GOLD);
   ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,bg,OBJPROP_ZORDER,1000);

   if(ObjectFind(0,tx)<0)
      ObjectCreate(0,tx,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,tx,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,tx,OBJPROP_XDISTANCE,x+padX);
   ObjectSetInteger(0,tx,OBJPROP_YDISTANCE,y+padY);
   ObjectSetInteger(0,tx,OBJPROP_COLOR,C_GOLD);
   ObjectSetInteger(0,tx,OBJPROP_FONTSIZE,fs);
   ObjectSetString(0,tx,OBJPROP_FONT,"Arial Bold");
   ObjectSetString(0,tx,OBJPROP_TEXT,footer);
   ObjectSetInteger(0,tx,OBJPROP_ZORDER,1001);
   ObjectSetInteger(0,tx,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,tx,OBJPROP_HIDDEN,true);
}

void UpdateTemplateVisuals()
{
   UpdateDynamicDashboard();
   UpdateBrandFooter();
   DrawConfigurableEMALines(false);
   ChartRedraw(0);
}



int OnInit()
{
   if(!symInfo.Name(_Symbol)) return INIT_FAILED;
   symInfo.Refresh();
   g_digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   pipValue=(g_digits==3 || g_digits==5) ? _Point*10.0 : _Point;
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   handleFast=iMA(_Symbol,InpTF,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   handleSlow=iMA(_Symbol,InpTF,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   handleRSI=iRSI(_Symbol,InpTF,InpRSIPeriod,PRICE_CLOSE);
   handleATR=iATR(_Symbol,InpTF,14);
   if(handleFast==INVALID_HANDLE || handleSlow==INVALID_HANDLE ||
      handleRSI==INVALID_HANDLE || handleATR==INVALID_HANDLE)
   {
      Print("HFT-CaR: indicator initialization failed.");
      return INIT_FAILED;
   }

   // Draw EMA curves as chart objects so their colours and thickness are configurable.
   // These visual handles use the chart timeframe; trading signals still use InpTF.
   handleVisualFast=iMA(_Symbol,_Period,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   handleVisualSlow=iMA(_Symbol,_Period,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   if(handleVisualFast==INVALID_HANDLE || handleVisualSlow==INVALID_HANDLE)
   {
      Print("HFT-CaR: visual EMA initialization failed. Error ",GetLastError());
      return INIT_FAILED;
   }

   startEquity=peakEquity=dailyStartEq=accInfo.Equity();
   EventSetTimer(1);
   DrawConfigurableEMALines(true);
   UpdateTemplateVisuals();
   Print("ALPHENTRA HFT-CaR initialized.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(handleFast!=INVALID_HANDLE) IndicatorRelease(handleFast);
   if(handleSlow!=INVALID_HANDLE) IndicatorRelease(handleSlow);
   if(handleRSI!=INVALID_HANDLE) IndicatorRelease(handleRSI);
   if(handleATR!=INVALID_HANDLE) IndicatorRelease(handleATR);
   if(handleVisualFast!=INVALID_HANDLE) IndicatorRelease(handleVisualFast);
   if(handleVisualSlow!=INVALID_HANDLE) IndicatorRelease(handleVisualSlow);
   ObjectsDeleteAll(0,PREFIX);
   ChartRedraw(0);
}

void OnTimer()
{
   // Configurable EMA chart visuals run independently of AutoTrading and trade filters.
   DrawConfigurableEMALines(false);
   CheckEquityProtection();
   UpdateTemplateVisuals();
}

void OnTick()
{
   static int lastDateKey=-1;
   MqlDateTime dt; TimeCurrent(dt);
   int dateKey=dt.year*1000+dt.day_of_year;
   if(dateKey!=lastDateKey)
   {
      lastDateKey=dateKey;
      dailyStartEq=accInfo.Equity();
   }

   // Keep configurable EMA chart visuals updated before execution/risk gates.
   DrawConfigurableEMALines(false);

   if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpreadPoints)
   {
      statusText="Spread high";
      return;
   }

   if(!tradingEnabled) return;

   CAR_HandleCooldown();

   // A pending limit order may fill while the cycle is IDLE.
   // Detect that fill and initialize the CaR cycle before monitoring it.
   if(g_carState==CAR_IDLE && HasOurPosition())
   {
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         if(posInfo.SelectByIndex(i) && posInfo.Symbol()==_Symbol &&
            posInfo.Magic()==InpMagic)
         {
            g_carDir=(posInfo.PositionType()==POSITION_TYPE_BUY ? 1 : -1);
            g_carLot=posInfo.Volume();
            g_carStep=1;
            g_carDebt=0;
            g_carState=CAR_RECOVERING;
            g_carTime=TimeCurrent();
            statusText="CaR limit entry active";
            break;
         }
      }
   }

   CAR_Monitor();
   ManagePendingTimeout();

   if(g_carState==CAR_IDLE && !HasOurPosition() && !HasPendingOrder())
   {
      int signal=GetSignal();
      if(signal!=0)
      {
         lastSignalDir=signal;
         if(InpUseLimitOrders) PlaceLimitEntry(signal);
         else CAR_OpenFirst(signal);
      }
   }
}

void OnChartEvent(const int id,const long &lparam,
                  const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_CLICK &&
      (sparam==PREFIX+"BRAND_BG" || sparam==PREFIX+"BRAND_TX"))
   {
      MessageBox("ALPHENTRA AI | TRADE BEYOND LIMITS.\n"
                 "Join our official Telegram channel:\n"
                 "https://t.me/Alphentra",
                 "ALPHENTRA AI",MB_OK|MB_ICONINFORMATION);
      ObjectSetInteger(0,sparam,OBJPROP_SELECTED,false);
      ChartRedraw(0);
   }
   if(id==CHARTEVENT_CHART_CHANGE)
   {
      g_lastEMADrawBar=0;
      DrawConfigurableEMALines(true);
      UpdateTemplateVisuals();
   }
}


//+------------------------------------------------------------------+
// CONFIGURABLE EMA CHART LINES
// Each EMA is rendered as connected OBJ_TREND segments. This avoids the
// fixed styling of the built-in indicator and allows independent colours
// and line widths directly from the EA Inputs.
//+------------------------------------------------------------------+
void DeleteEMALineObjects(const string tag)
{
   string prefix=PREFIX+tag+"_";
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--)
   {
      string name=ObjectName(0,i,0,-1);
      if(StringFind(name,prefix)==0)
         ObjectDelete(0,name);
   }
}

void DrawOneEMALine(const string tag,const int indicatorHandle,
                    const color lineColor,const int lineWidth)
{
   DeleteEMALineObjects(tag);
   if(indicatorHandle==INVALID_HANDLE) return;

   int requested=MathMax(20,MathMin(InpEMADisplayBars,1500));
   int available=Bars(_Symbol,_Period);
   int count=MathMin(requested,available);
   if(count<3) return;

   datetime times[];
   double values[];
   ArraySetAsSeries(times,true);
   ArraySetAsSeries(values,true);
   int copiedTimes=CopyTime(_Symbol,_Period,0,count,times);
   int copiedValues=CopyBuffer(indicatorHandle,0,0,count,values);
   int copied=MathMin(copiedTimes,copiedValues);
   if(copied<3) return;

   int width=MathMax(1,MathMin(lineWidth,5));
   // Draw oldest segment first; newer segments are painted over it.
   for(int bar=copied-1;bar>=1;bar--)
   {
      if(times[bar]<=0 || times[bar-1]<=0 ||
         values[bar]==EMPTY_VALUE || values[bar-1]==EMPTY_VALUE)
         continue;

      string name=PREFIX+tag+"_"+IntegerToString((long)times[bar]);
      if(!ObjectCreate(0,name,OBJ_TREND,0,
                       times[bar],values[bar],times[bar-1],values[bar-1]))
      {
         Print("HFT-CaR: failed to draw ",tag," EMA segment. Error ",GetLastError());
         continue;
      }
      ObjectSetInteger(0,name,OBJPROP_COLOR,lineColor);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      // Keep EMA segments behind chart foreground objects so they never
      // paint over the dashboard panel, labels, or other foreground UI.
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_ZORDER,5);
   }
}

void DrawConfigurableEMALines(const bool forceRedraw=false)
{
   datetime currentBar=iTime(_Symbol,_Period,0);
   if(currentBar<=0) return;
   if(!forceRedraw && currentBar==g_lastEMADrawBar) return;
   g_lastEMADrawBar=currentBar;

   if(InpShowFastEMA)
      DrawOneEMALine("EMA_FAST",handleVisualFast,InpFastEMAColor,InpFastEMAWidth);
   else
      DeleteEMALineObjects("EMA_FAST");

   if(InpShowSlowEMA)
      DrawOneEMALine("EMA_SLOW",handleVisualSlow,InpSlowEMAColor,InpSlowEMAWidth);
   else
      DeleteEMALineObjects("EMA_SLOW");
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// SIGNAL
//+------------------------------------------------------------------+
int GetSignal()
{
   double fast[], slow[], rsi[];
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   ArraySetAsSeries(rsi, true);

   if(CopyBuffer(handleFast, 0, 0, 3, fast) < 3) return 0;
   if(CopyBuffer(handleSlow, 0, 0, 3, slow) < 3) return 0;
   if(CopyBuffer(handleRSI,  0, 0, 3, rsi)  < 3) return 0;

   bool bull = (fast[1] > slow[1]) && (rsi[1] < InpRSIBuyMax);
   bool bear = (fast[1] < slow[1]) && (rsi[1] > InpRSISellMin);

   if(InpUseOddEvenBias)
   {
      MqlDateTime d; TimeCurrent(d);
      bool odd = (d.day % 2 != 0);
      if(bull && !odd) return 0;
      if(bear &&  odd) return 0;
   }

   if(bull) { lastSignal = "BUY"; return 1; }
   if(bear) { lastSignal = "SELL"; return -1; }
   return 0;
}

//+------------------------------------------------------------------+
// FIXED LIMIT ORDER PLACEMENT
//+------------------------------------------------------------------+
void PlaceLimitEntry(int dir)
{
   if(HasPendingOrder()) return;

   long stopsLevel  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDist   = MathMax(stopsLevel, freezeLevel) * _Point;
   if(minDist < 10 * _Point) minDist = 10 * _Point;   // safety

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double offset = MathMax(InpLimitOffsetPips * pipValue, minDist * 1.5);

   double price, tp;
   double tpDist = MathMax(InpDistancePoints * 0.35 * _Point, minDist * 2.0);

   string cmt = "Limit|" + lastSignal;

   if(dir > 0) // Buy Limit
   {
      price = NormalizeDouble(bid - offset, g_digits);
      // Extra safety: must be below current Bid
      if(price >= bid - minDist)
         price = NormalizeDouble(bid - minDist * 1.8, g_digits);

      tp = NormalizeDouble(price + tpDist, g_digits);

      if(!trade.BuyLimit(InpInitialLot, price, _Symbol, 0, tp, ORDER_TIME_GTC, 0, cmt))
      {
         Print("BuyLimit FAILED: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         Print("Price=", price, " Bid=", bid, " minDist=", minDist);
         statusText = "Limit rejected";
      }
      else
      {
         pendingPlaceTime = TimeCurrent();
         statusText = "Buy Limit OK";
         if(InpDebug) Print("Buy Limit placed @ ", price, " TP=", tp);
      }
   }
   else // Sell Limit
   {
      price = NormalizeDouble(ask + offset, g_digits);
      if(price <= ask + minDist)
         price = NormalizeDouble(ask + minDist * 1.8, g_digits);

      tp = NormalizeDouble(price - tpDist, g_digits);

      if(!trade.SellLimit(InpInitialLot, price, _Symbol, 0, tp, ORDER_TIME_GTC, 0, cmt))
      {
         Print("SellLimit FAILED: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         Print("Price=", price, " Ask=", ask, " minDist=", minDist);
         statusText = "Limit rejected";
      }
      else
      {
         pendingPlaceTime = TimeCurrent();
         statusText = "Sell Limit OK";
         if(InpDebug) Print("Sell Limit placed @ ", price, " TP=", tp);
      }
   }
}

//+------------------------------------------------------------------+
bool HasPendingOrder()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(orderInfo.SelectByIndex(i))
         if(orderInfo.Symbol() == _Symbol && orderInfo.Magic() == InpMagic)
            return true;
   }
   return false;
}

bool HasOurPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagic)
            return true;
   }
   return false;
}

void ManagePendingTimeout()
{
   if(!HasPendingOrder()) return;

   // Cancel if too old (in bars)
   datetime barTime = iTime(_Symbol, InpTF, 0);
   static datetime lastBar = 0;
   static int barsAlive = 0;

   if(barTime != lastBar)
   {
      lastBar = barTime;
      barsAlive++;
   }

   if(barsAlive >= InpLimitMaxBars)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(orderInfo.SelectByIndex(i) && orderInfo.Symbol() == _Symbol && orderInfo.Magic() == InpMagic)
         {
            trade.OrderDelete(orderInfo.Ticket());
            if(InpDebug) Print("Pending cancelled by timeout");
            statusText = "Limit timeout";
         }
      }
      barsAlive = 0;
   }

   // Also cancel if signal completely reversed
   int currentSig = GetSignal();
   if(currentSig != 0 && currentSig != lastSignalDir)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(orderInfo.SelectByIndex(i) && orderInfo.Symbol() == _Symbol && orderInfo.Magic() == InpMagic)
            trade.OrderDelete(orderInfo.Ticket());
      }
      if(InpDebug) Print("Pending cancelled – signal reversed");
   }
}

//+------------------------------------------------------------------+
// CaR ENGINE (same robust version)
//+------------------------------------------------------------------+
double CAR_GetDistance()
{
   if(!InpUseATRDistance) return InpDistancePoints;
   double atr[1];
   if(CopyBuffer(handleATR, 0, 0, 1, atr) < 1) return InpDistancePoints;
   double d = (atr[0] / _Point) * InpATRMultDist;
   return MathMax(40, MathMin(d, 350));
}

bool CAR_OpenFirst(int dir)
{
   if(g_carState != CAR_IDLE) return false;
   if(InpRequireProfit && !g_lastProfit) return false;

   g_carLot  = InpInitialLot;
   g_carStep = 1;
   g_carDir  = dir;
   g_carDebt = 0;

   double price = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tpPts = InpTPBufferPoints + CAR_GetDistance() * 0.3;
   double tp    = NormalizeDouble((dir > 0) ? price + tpPts*_Point : price - tpPts*_Point, g_digits);

   string cmt = StringFormat("CaR_S1_%s", dir > 0 ? "B" : "S");
   bool ok = (dir > 0) ? trade.Buy(g_carLot, _Symbol, price, 0, tp, cmt)
                       : trade.Sell(g_carLot, _Symbol, price, 0, tp, cmt);

   if(ok)
   {
      g_carState = CAR_RECOVERING;
      g_carTime  = TimeCurrent();
      statusText = "CaR Market started";
      return true;
   }
   return false;
}

void CAR_Monitor()
{
   if(g_carState != CAR_RECOVERING) return;

   ulong ticket = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i) && posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagic)
      { ticket = posInfo.Ticket(); break; }
   }

   if(ticket == 0)
   {
      // Closed by TP
      HistorySelect(g_carTime, TimeCurrent()+30);
      double lastProfit = 0;
      for(int i = HistoryDealsTotal()-1; i >= 0; i--)
      {
         ulong d = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(d, DEAL_MAGIC) == InpMagic && HistoryDealGetString(d, DEAL_SYMBOL) == _Symbol)
         {
            lastProfit = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_COMMISSION);
            break;
         }
      }

      if(lastProfit >= 0)
      {
         g_lastProfit = true;
         g_carState = CAR_COOLDOWN;
         g_carTime = TimeCurrent();
         statusText = "Cycle WIN";
      }
      else
      {
         g_carDebt += MathAbs(lastProfit);
         CAR_Advance();
      }
      return;
   }

   if(!posInfo.SelectByTicket(ticket)) return;

   double open = posInfo.PriceOpen();
   double price = (posInfo.PositionType() == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double movePts = (posInfo.PositionType() == POSITION_TYPE_BUY) ? (open - price)/_Point : (price - open)/_Point;

   if(movePts >= CAR_GetDistance())
   {
      if(trade.PositionClose(ticket))
      {
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double moneyPerPt = (tickValue / tickSize) * _Point * g_carLot;
         g_carDebt += movePts * moneyPerPt;
         CAR_Advance();
      }
   }
}

void CAR_Advance()
{
   g_carStep++;
   if(g_carStep > InpMaxSteps)
   {
      g_lastProfit = false;
      g_carState = CAR_COOLDOWN;
      g_carTime = TimeCurrent();
      statusText = "Circuit Breaker";
      return;
   }

   g_carDir *= -1;
   g_carLot = NormalizeDouble(g_carLot * InpMultiplier, 2);

   double price = (g_carDir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double moneyPerPt = (tickValue / tickSize) * _Point * g_carLot;
   double tpPts = (moneyPerPt > 0) ? (g_carDebt + 5.0) / moneyPerPt : 15;
   tpPts = MathMax(8, MathMin(tpPts, 400));

   double tp = NormalizeDouble((g_carDir > 0) ? price + tpPts*_Point : price - tpPts*_Point, g_digits);
   string cmt = StringFormat("CaR_S%d_%s", g_carStep, g_carDir > 0 ? "B" : "S");

   bool ok = (g_carDir > 0) ? trade.Buy(g_carLot, _Symbol, price, 0, tp, cmt)
                            : trade.Sell(g_carLot, _Symbol, price, 0, tp, cmt);

   if(ok)
   {
      g_carState = CAR_RECOVERING;
      g_carTime = TimeCurrent();
      statusText = "Recovering #" + IntegerToString(g_carStep);
   }
}

void CAR_HandleCooldown()
{
   if(g_carState != CAR_COOLDOWN) return;
   if(TimeCurrent() - g_carTime >= InpCooldownSec)
   {
      g_carState = CAR_IDLE;
      g_carDebt = g_carLot = 0;
      g_carStep = g_carDir = 0;
      statusText = "Ready";
   }
}
//+------------------------------------------------------------------+
void CheckEquityProtection()
{
   double eq = accInfo.Equity();
   if(eq > peakEquity) peakEquity = eq;

   if((peakEquity - eq) / peakEquity * 100.0 >= InpMaxDrawdownPct)
   {
      tradingEnabled = false;
      CloseAll();
      statusText = "Max DD";
   }

   double dailyPL = (eq - dailyStartEq) / dailyStartEq * 100.0;
   if(dailyPL <= -InpMaxDailyLossPct)
   {
      tradingEnabled = false;
      statusText = "Daily loss limit";
   }
}

void CloseAll()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(posInfo.SelectByIndex(i) && posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagic)
         trade.PositionClose(posInfo.Ticket());

   for(int i = OrdersTotal()-1; i >= 0; i--)
      if(orderInfo.SelectByIndex(i) && orderInfo.Symbol() == _Symbol && orderInfo.Magic() == InpMagic)
         trade.OrderDelete(orderInfo.Ticket());

   g_carState = CAR_IDLE;
}
