//+------------------------------------------------------------------+|
//|                                                                  |
//|                                                                  |
//|                                                                  |
//|                    A L P H E N T R A   A I                       |
//|                                                                  |
//|                     TRADE BEYOND LIMITS.                         |
//|                                                                  |
//|              DTC PRO - MULTI-TIMEFRAME TREND SIGNALS             |                     
//|  --------------------------------------------------------------  |
//|                                                                  |
//|  PRODUCT  : DTC PRO                                              |
//|  DEVELOPER: ALPHENTRA AI                                         |
//|  ENGINE   : INTEGRATED SMC + EMA + MTF + ALGO                    |
//|                                                                  |
//|  FEATURES    : EMA RIBBON, MTF DASHBOARD, ENTRY / SL / TP1-TP4   |
//|                CLOSED-BAR SIGNALS, ALERTS                        |
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
#property link      "https://alphentra.ai"
#property version   "2.00"
#property strict
#property description "DTC PRO by Alphentra AI | TRADE BEYOND LIMITS."
#property description "Six-EMA trend, multi-timeframe dashboard and trade-level visualization."

#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   6

//--- Plot settings
#property indicator_label1  "EMA 30"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#property indicator_label2  "EMA 35"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLime
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "EMA 40"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLime
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "EMA 45"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrLime
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

#property indicator_label5  "EMA 50"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrLime
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label6  "EMA 60"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrLime
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+
input group "=== EMA Settings ==="
input int    InpEMA1 = 30;        // EMA 1
input int    InpEMA2 = 35;        // EMA 2
input int    InpEMA3 = 40;        // EMA 3
input int    InpEMA4 = 45;        // EMA 4
input int    InpEMA5 = 50;        // EMA 5
input int    InpEMA6 = 60;        // EMA 6

input group "=== Multi-Timeframe Settings ==="
input ENUM_TIMEFRAMES TF1 = PERIOD_M15;  // 15M
input ENUM_TIMEFRAMES TF2 = PERIOD_M30;  // 30M
input ENUM_TIMEFRAMES TF3 = PERIOD_H1;   // 1H
input ENUM_TIMEFRAMES TF4 = PERIOD_H4;   // 4H
input ENUM_TIMEFRAMES TF5 = PERIOD_D1;   // Daily

input group "=== Risk Management ==="
input string InpSLLookback = "Mid";      // Stop-Loss Lookback (Tiny/Small/Mid/Large)
input double InpStopLossPct = 0.25;      // Stop Loss %
input double InpTP1Mult = 1.0;           // TP1 Multiplier
input double InpTP2Mult = 2.0;           // TP2 Multiplier
input double InpTP3Mult = 3.0;           // TP3 Multiplier
input double InpTP4Mult = 4.0;           // TP4 Multiplier

input group "=== Display Settings ==="
input int    InpLineLength = 15;         // Line Length (bars)
input bool   InpShowNumbers = true;      // Show Price Numbers
input bool   InpShowLabels  = true;      // Show Signal Labels

input group "=== ATR Filter ==="
input bool   InpUseATR = true;           // Enable ATR Filter
input int    InpATRPeriod = 14;          // ATR Period
input double InpATRMin = 0.0;            // Minimum ATR in price units; 0 disables the floor

input group "=== Dashboard ==="
input bool   InpShowDashboard = true;    // Show Multi-Timeframe Dashboard
input int    InpDashboardX = 12;          // Dashboard left offset
input int    InpDashboardY = 22;          // Dashboard top offset
input int    InpDashboardWidth = 310;     // Dashboard width

//+------------------------------------------------------------------+
//| Global buffers                                                   |
//+------------------------------------------------------------------+
double EMA1Buffer[];
double EMA2Buffer[];
double EMA3Buffer[];
double EMA4Buffer[];
double EMA5Buffer[];
double EMA6Buffer[];

// Handles
int handleEMA1, handleEMA2, handleEMA3, handleEMA4, handleEMA5, handleEMA6;
int handleATR;

// Cached higher-timeframe handles (created once, released on deinitialization)
int handleTF1EMA20 = INVALID_HANDLE, handleTF1EMA50 = INVALID_HANDLE;
int handleTF2EMA20 = INVALID_HANDLE, handleTF2EMA50 = INVALID_HANDLE;
int handleTF3EMA20 = INVALID_HANDLE, handleTF3EMA50 = INVALID_HANDLE;
int handleTF4EMA20 = INVALID_HANDLE, handleTF4EMA50 = INVALID_HANDLE;
int handleTF5EMA20 = INVALID_HANDLE, handleTF5EMA50 = INVALID_HANDLE;

// Prevent duplicate processing of the same confirmed candle
datetime lastSignalBarTime = 0;

// Objects names
string prefix = "ALPH_DTC_PRO_";

// SL lookback length
int sl_length = 8;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpEMA1 <= 0 || InpEMA2 <= 0 || InpEMA3 <= 0 ||
      InpEMA4 <= 0 || InpEMA5 <= 0 || InpEMA6 <= 0 ||
      InpATRPeriod <= 0 || InpLineLength < 1 ||
      InpTP1Mult <= 0.0 || InpTP2Mult <= 0.0 ||
      InpTP3Mult <= 0.0 || InpTP4Mult <= 0.0 ||
      InpStopLossPct <= 0.0 || InpATRMin < 0.0)
   {
      Print("DTC PRO: Invalid input parameter. Check EMA, ATR, line and risk settings.");
      return(INIT_PARAMETERS_INCORRECT);
   }

   SetIndexBuffer(0, EMA1Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, EMA2Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, EMA3Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, EMA4Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, EMA5Buffer, INDICATOR_DATA);
   SetIndexBuffer(5, EMA6Buffer, INDICATOR_DATA);

   ArraySetAsSeries(EMA1Buffer, true);
   ArraySetAsSeries(EMA2Buffer, true);
   ArraySetAsSeries(EMA3Buffer, true);
   ArraySetAsSeries(EMA4Buffer, true);
   ArraySetAsSeries(EMA5Buffer, true);
   ArraySetAsSeries(EMA6Buffer, true);

   handleEMA1 = iMA(_Symbol, PERIOD_CURRENT, InpEMA1, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA2 = iMA(_Symbol, PERIOD_CURRENT, InpEMA2, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA3 = iMA(_Symbol, PERIOD_CURRENT, InpEMA3, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA4 = iMA(_Symbol, PERIOD_CURRENT, InpEMA4, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA5 = iMA(_Symbol, PERIOD_CURRENT, InpEMA5, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA6 = iMA(_Symbol, PERIOD_CURRENT, InpEMA6, 0, MODE_EMA, PRICE_CLOSE);
   handleATR  = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);

   handleTF1EMA20 = iMA(_Symbol, TF1, 20, 0, MODE_EMA, PRICE_CLOSE);
   handleTF1EMA50 = iMA(_Symbol, TF1, 50, 0, MODE_EMA, PRICE_CLOSE);
   handleTF2EMA20 = iMA(_Symbol, TF2, 20, 0, MODE_EMA, PRICE_CLOSE);
   handleTF2EMA50 = iMA(_Symbol, TF2, 50, 0, MODE_EMA, PRICE_CLOSE);
   handleTF3EMA20 = iMA(_Symbol, TF3, 20, 0, MODE_EMA, PRICE_CLOSE);
   handleTF3EMA50 = iMA(_Symbol, TF3, 50, 0, MODE_EMA, PRICE_CLOSE);
   handleTF4EMA20 = iMA(_Symbol, TF4, 20, 0, MODE_EMA, PRICE_CLOSE);
   handleTF4EMA50 = iMA(_Symbol, TF4, 50, 0, MODE_EMA, PRICE_CLOSE);
   handleTF5EMA20 = iMA(_Symbol, TF5, 20, 0, MODE_EMA, PRICE_CLOSE);
   handleTF5EMA50 = iMA(_Symbol, TF5, 50, 0, MODE_EMA, PRICE_CLOSE);

   if(handleEMA1 == INVALID_HANDLE || handleEMA2 == INVALID_HANDLE ||
      handleEMA3 == INVALID_HANDLE || handleEMA4 == INVALID_HANDLE ||
      handleEMA5 == INVALID_HANDLE || handleEMA6 == INVALID_HANDLE ||
      handleATR  == INVALID_HANDLE ||
      handleTF1EMA20 == INVALID_HANDLE || handleTF1EMA50 == INVALID_HANDLE ||
      handleTF2EMA20 == INVALID_HANDLE || handleTF2EMA50 == INVALID_HANDLE ||
      handleTF3EMA20 == INVALID_HANDLE || handleTF3EMA50 == INVALID_HANDLE ||
      handleTF4EMA20 == INVALID_HANDLE || handleTF4EMA50 == INVALID_HANDLE ||
      handleTF5EMA20 == INVALID_HANDLE || handleTF5EMA50 == INVALID_HANDLE)
   {
      Print("DTC PRO: Error creating one or more indicator handles.");
      return(INIT_FAILED);
   }

   // SL lookback
   if(InpSLLookback == "Tiny")  sl_length = 3;
   else if(InpSLLookback == "Small") sl_length = 5;
   else if(InpSLLookback == "Mid")   sl_length = 8;
   else if(InpSLLookback == "Large") sl_length = 12;
   else sl_length = 8;

   IndicatorSetString(INDICATOR_SHORTNAME, "ALPHENTRA AI - DTC PRO v2.00");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   // Clean old objects
   ObjectsDeleteAll(0, prefix);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, prefix);
   Comment("");

   if(handleEMA1 != INVALID_HANDLE) IndicatorRelease(handleEMA1);
   if(handleEMA2 != INVALID_HANDLE) IndicatorRelease(handleEMA2);
   if(handleEMA3 != INVALID_HANDLE) IndicatorRelease(handleEMA3);
   if(handleEMA4 != INVALID_HANDLE) IndicatorRelease(handleEMA4);
   if(handleEMA5 != INVALID_HANDLE) IndicatorRelease(handleEMA5);
   if(handleEMA6 != INVALID_HANDLE) IndicatorRelease(handleEMA6);
   if(handleATR  != INVALID_HANDLE) IndicatorRelease(handleATR);

   if(handleTF1EMA20 != INVALID_HANDLE) IndicatorRelease(handleTF1EMA20);
   if(handleTF1EMA50 != INVALID_HANDLE) IndicatorRelease(handleTF1EMA50);
   if(handleTF2EMA20 != INVALID_HANDLE) IndicatorRelease(handleTF2EMA20);
   if(handleTF2EMA50 != INVALID_HANDLE) IndicatorRelease(handleTF2EMA50);
   if(handleTF3EMA20 != INVALID_HANDLE) IndicatorRelease(handleTF3EMA20);
   if(handleTF3EMA50 != INVALID_HANDLE) IndicatorRelease(handleTF3EMA50);
   if(handleTF4EMA20 != INVALID_HANDLE) IndicatorRelease(handleTF4EMA20);
   if(handleTF4EMA50 != INVALID_HANDLE) IndicatorRelease(handleTF4EMA50);
   if(handleTF5EMA20 != INVALID_HANDLE) IndicatorRelease(handleTF5EMA20);
   if(handleTF5EMA50 != INVALID_HANDLE) IndicatorRelease(handleTF5EMA50);
}

//+------------------------------------------------------------------+
//| Main calculation function                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 100) return(0);

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   // Copy EMAs
   if(CopyBuffer(handleEMA1, 0, 0, rates_total, EMA1Buffer) <= 0) return(0);
   if(CopyBuffer(handleEMA2, 0, 0, rates_total, EMA2Buffer) <= 0) return(0);
   if(CopyBuffer(handleEMA3, 0, 0, rates_total, EMA3Buffer) <= 0) return(0);
   if(CopyBuffer(handleEMA4, 0, 0, rates_total, EMA4Buffer) <= 0) return(0);
   if(CopyBuffer(handleEMA5, 0, 0, rates_total, EMA5Buffer) <= 0) return(0);
   if(CopyBuffer(handleEMA6, 0, 0, rates_total, EMA6Buffer) <= 0) return(0);

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(handleATR, 0, 0, rates_total, atr) <= 0) return(0);

   // Evaluate only the most recently closed candle. This avoids intrabar
   // signal changes and duplicate drawings on repeated ticks.
   if(rates_total > sl_length + 3 && time[1] != lastSignalBarTime)
   {
      const int i = 1;
      bool bullish = (EMA1Buffer[i] > EMA2Buffer[i] &&
                      EMA2Buffer[i] > EMA3Buffer[i] &&
                      EMA3Buffer[i] > EMA4Buffer[i] &&
                      EMA4Buffer[i] > EMA5Buffer[i] &&
                      EMA5Buffer[i] > EMA6Buffer[i]);

      bool bearish = (EMA1Buffer[i] < EMA2Buffer[i] &&
                      EMA2Buffer[i] < EMA3Buffer[i] &&
                      EMA3Buffer[i] < EMA4Buffer[i] &&
                      EMA4Buffer[i] < EMA5Buffer[i] &&
                      EMA5Buffer[i] < EMA6Buffer[i]);

      bool prev_bullish = (EMA1Buffer[2] > EMA2Buffer[2] &&
                           EMA2Buffer[2] > EMA3Buffer[2] &&
                           EMA3Buffer[2] > EMA4Buffer[2] &&
                           EMA4Buffer[2] > EMA5Buffer[2] &&
                           EMA5Buffer[2] > EMA6Buffer[2]);

      bool prev_bearish = (EMA1Buffer[2] < EMA2Buffer[2] &&
                           EMA2Buffer[2] < EMA3Buffer[2] &&
                           EMA3Buffer[2] < EMA4Buffer[2] &&
                           EMA4Buffer[2] < EMA5Buffer[2] &&
                           EMA5Buffer[2] < EMA6Buffer[2]);

      bool atr_ok = (!InpUseATR || atr[i] > 0.0);
      if(InpUseATR && InpATRMin > 0.0)
         atr_ok = (atr[i] >= InpATRMin);

      bool long_signal  = (!prev_bullish && bullish && atr_ok);
      bool short_signal = (!prev_bearish && bearish && atr_ok);

      if(long_signal || short_signal)
      {
         double swingLow = low[i];
         double swingHigh = high[i];
         for(int j = i; j < i + sl_length && j < rates_total; j++)
         {
            if(low[j] < swingLow) swingLow = low[j];
            if(high[j] > swingHigh) swingHigh = high[j];
         }

         if(long_signal)
         {
            CreateTradeLevels(true, close[i], time[i], atr[i], swingLow);
            if(InpShowLabels)
               CreateSignalLabel(true, time[i], low[i] - atr[i] * 0.5);
         }
         else if(short_signal)
         {
            CreateTradeLevels(false, close[i], time[i], atr[i], swingHigh);
            if(InpShowLabels)
               CreateSignalLabel(false, time[i], high[i] + atr[i] * 0.5);
         }
      }

      lastSignalBarTime = time[1];
   }

   // Update Dashboard and persistent Alphentra chart footer
   if(InpShowDashboard)
      UpdateDashboard();

   DrawAlphentraFooter();

   // Color EMAs based on current trend (visual feedback)
   bool current_bull = (EMA1Buffer[0] > EMA2Buffer[0] && EMA2Buffer[0] > EMA3Buffer[0] &&
                        EMA3Buffer[0] > EMA4Buffer[0] && EMA4Buffer[0] > EMA5Buffer[0] &&
                        EMA5Buffer[0] > EMA6Buffer[0]);
   bool current_bear = (EMA1Buffer[0] < EMA2Buffer[0] && EMA2Buffer[0] < EMA3Buffer[0] &&
                        EMA3Buffer[0] < EMA4Buffer[0] && EMA4Buffer[0] < EMA5Buffer[0] &&
                        EMA5Buffer[0] < EMA6Buffer[0]);

   color emaCol = current_bull ? clrLime : (current_bear ? clrRed : clrGray);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, emaCol);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, emaCol);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, emaCol);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, emaCol);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, emaCol);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, emaCol);

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Create Entry / SL / TP lines and labels                          |
//+------------------------------------------------------------------+
void CreateTradeLevels(bool isLong, double entryPrice, datetime signalTime, double atrVal, double swingPrice)
{
   // Delete previous levels
   ObjectsDeleteAll(0, prefix + "LVL_");

   double sl, tp1, tp2, tp3, tp4;
   double fallbackRisk = entryPrice * InpStopLossPct / 100.0;

   if(isLong)
   {
      sl = swingPrice;
      if(sl <= 0.0 || sl >= entryPrice)
         sl = entryPrice - fallbackRisk;
      // Keep the structural stop at least as protective as the configured
      // percentage fallback; targets are then calculated from actual risk.
      if(sl > entryPrice - fallbackRisk)
         sl = entryPrice - fallbackRisk;

      double riskDistance = entryPrice - sl;
      tp1 = entryPrice + riskDistance * InpTP1Mult;
      tp2 = entryPrice + riskDistance * InpTP2Mult;
      tp3 = entryPrice + riskDistance * InpTP3Mult;
      tp4 = entryPrice + riskDistance * InpTP4Mult;
   }
   else
   {
      sl = swingPrice;
      if(sl <= entryPrice)
         sl = entryPrice + fallbackRisk;
      if(sl < entryPrice + fallbackRisk)
         sl = entryPrice + fallbackRisk;

      double riskDistance = sl - entryPrice;
      tp1 = entryPrice - riskDistance * InpTP1Mult;
      tp2 = entryPrice - riskDistance * InpTP2Mult;
      tp3 = entryPrice - riskDistance * InpTP3Mult;
      tp4 = entryPrice - riskDistance * InpTP4Mult;
   }

   sl  = NormalizeDouble(sl, _Digits);
   tp1 = NormalizeDouble(tp1, _Digits);
   tp2 = NormalizeDouble(tp2, _Digits);
   tp3 = NormalizeDouble(tp3, _Digits);
   tp4 = NormalizeDouble(tp4, _Digits);

   datetime t2 = signalTime + PeriodSeconds() * InpLineLength;

   // Entry
   CreateHLine(prefix + "LVL_ENTRY", entryPrice, clrDodgerBlue, "ENTRY");
   // SL
   CreateHLine(prefix + "LVL_SL", sl, clrRed, "SL");
   // TPs
   CreateHLine(prefix + "LVL_TP1", tp1, clrLime, "TP1");
   CreateHLine(prefix + "LVL_TP2", tp2, clrLime, "TP2");
   CreateHLine(prefix + "LVL_TP3", tp3, clrLime, "TP3");
   CreateHLine(prefix + "LVL_TP4", tp4, clrLime, "TP4");

   if(InpShowNumbers)
   {
      CreatePriceLabel(prefix + "LVL_LBL_ENTRY", entryPrice, t2, "ENTRY\n" + DoubleToString(entryPrice, _Digits), clrDodgerBlue);
      CreatePriceLabel(prefix + "LVL_LBL_SL",    sl,         t2, "SL\n"    + DoubleToString(sl, _Digits),         clrRed);
      CreatePriceLabel(prefix + "LVL_LBL_TP1",   tp1,        t2, "TP1\n"   + DoubleToString(tp1, _Digits),        clrLime);
      CreatePriceLabel(prefix + "LVL_LBL_TP2",   tp2,        t2, "TP2\n"   + DoubleToString(tp2, _Digits),        clrLime);
      CreatePriceLabel(prefix + "LVL_LBL_TP3",   tp3,        t2, "TP3\n"   + DoubleToString(tp3, _Digits),        clrLime);
      CreatePriceLabel(prefix + "LVL_LBL_TP4",   tp4,        t2, "TP4\n"   + DoubleToString(tp4, _Digits),        clrLime);
   }
}

//+------------------------------------------------------------------+
//| Helper: Horizontal line                                          |
//+------------------------------------------------------------------+
void CreateHLine(string name, double price, color clr, string text)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Helper: Price label                                              |
//+------------------------------------------------------------------+
void CreatePriceLabel(string name, double price, datetime time, string text, color clr)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| Signal label (BUY / SELL)                                        |
//+------------------------------------------------------------------+
void CreateSignalLabel(bool isBuy, datetime time, double price)
{
   string name = prefix + "SIG_" + IntegerToString(TimeCurrent());
   ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
   ObjectSetString(0, name, OBJPROP_TEXT, isBuy ? "BUY" : "SELL");
   ObjectSetInteger(0, name, OBJPROP_COLOR, isBuy ? clrLime : clrRed);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Multi-Timeframe Dashboard                                        |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   const color panelBG = C'1,0,0';
   const color gold    = C'255,193,7';
   const color green   = C'0,230,118';
   const color red     = C'255,82,82';
   const color muted   = C'145,150,160';

   const string panel = prefix + "DASH_BG";

   if(ObjectFind(0, panel) < 0)
      ObjectCreate(0, panel, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, panel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel, OBJPROP_XDISTANCE, InpDashboardX);
   ObjectSetInteger(0, panel, OBJPROP_YDISTANCE, InpDashboardY);
   ObjectSetInteger(0, panel, OBJPROP_XSIZE, InpDashboardWidth);
   ObjectSetInteger(0, panel, OBJPROP_YSIZE, 225);
   ObjectSetInteger(0, panel, OBJPROP_BGCOLOR, panelBG);
   ObjectSetInteger(0, panel, OBJPROP_COLOR, gold);
   ObjectSetInteger(0, panel, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, panel, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, panel, OBJPROP_BACK, false);
   ObjectSetInteger(0, panel, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, panel, OBJPROP_HIDDEN, true);

   DashboardLabel("TITLE", InpDashboardX+9, InpDashboardY+8,
                  "ALPHENTRA  |  DTC PRO v2.00",
                  gold, 11, "Arial Bold");

   DashboardLabel("SUBTITLE", InpDashboardX+9, InpDashboardY+29,
                  _Symbol+"  |  "+EnumToString((ENUM_TIMEFRAMES)_Period)+
                  "  |  SIX-EMA TREND",
                  muted, 8, "Arial");

   DashboardLabel("DIVIDER", InpDashboardX+9, InpDashboardY+48,
                  "-------------------------------------------------------------------------------",
                  gold, 8, "Arial");

   string tfNames[5] = {"15M", "30M", "1H ", "4H ", "D1 "};
   string tfValues[5];

   tfValues[0] = GetTFTrend(handleTF1EMA20, handleTF1EMA50);
   tfValues[1] = GetTFTrend(handleTF2EMA20, handleTF2EMA50);
   tfValues[2] = GetTFTrend(handleTF3EMA20, handleTF3EMA50);
   tfValues[3] = GetTFTrend(handleTF4EMA20, handleTF4EMA50);
   tfValues[4] = GetTFTrend(handleTF5EMA20, handleTF5EMA50);

   for(int i=0; i<5; i++)
   {
      color stateColor = muted;
      string stateText = "LOADING";

      if(tfValues[i] == "BULLISH")
      {
         stateColor = green;
         stateText = "BULLISH  ▲";
      }
      else if(tfValues[i] == "BEARISH")
      {
         stateColor = red;
         stateText = "BEARISH  ▼";
      }
      else if(tfValues[i] == "NEUTRAL")
      {
         stateColor = gold;
         stateText = "NEUTRAL  -";
      }

      DashboardLabel("TF_"+IntegerToString(i)+"_NAME",
                     InpDashboardX+12, InpDashboardY+62+i*24,
                     tfNames[i], gold, 11, "Arial Bold");

      DashboardLabel("TF_"+IntegerToString(i)+"_STATE",
                     InpDashboardX+82, InpDashboardY+62+i*24,
                     stateText, stateColor, 11, "Arial Bold");
   }

      DashboardLabel("FOOTER_LINE", InpDashboardX+9, InpDashboardY+182,
                     "-------------------------------------------------------------------------------",
                     gold, 8, "Arial");
   
      DashboardLabel("FOOTER", InpDashboardX+9, InpDashboardY+197,
                     "ALPHENTRA AI  |  TRADE BEYOND LIMITS.",
                     gold, 8, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Alphentra AI chart footer - fixed to the bottom-right corner     |
//+------------------------------------------------------------------+
void DrawAlphentraFooter()
{
   string bg   = prefix + "BRAND_FOOTER_BG";
   string text = prefix + "BRAND_FOOTER_TEXT";

   // Create the footer background panel.
   if(ObjectFind(0, bg) < 0)
   {
      ResetLastError();
      if(!ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      {
         PrintFormat("DTC PRO: Footer background creation failed. Error=%d", GetLastError());
         return;
      }
   }

   // Use chart pixel dimensions and absolute coordinates, matching the
   // proven ELITE APEX Telegram badge positioning method.
   long chartWidth = 0, chartHeight = 0;
   if(!ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0, chartWidth) ||
      !ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0, chartHeight))
   {
      PrintFormat("DTC PRO: Cannot position footer. Chart size error=%d", GetLastError());
      return;
   }

   const int footerW = 160;
   const int footerH = 36;
   const int rightMargin = 14;
   const int bottomMargin = 20;

   int footerX = (int)chartWidth - rightMargin - footerW;
   int footerY = (int)chartHeight - bottomMargin - footerH;

   if(footerX < 0) footerX = 0;
   if(footerY < 0) footerY = 0;

   // Configure near-black footer background with a gold border.
   ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, footerW);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, footerH);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, footerX);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, footerY);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'1,0,0');       // #010000
   ObjectSetInteger(0, bg, OBJPROP_COLOR, C'255,193,7');     // Gold border
   ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg, OBJPROP_BACK, false);
   ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, bg, OBJPROP_ZORDER, 999);

   // Create footer text over the background.
   if(ObjectFind(0, text) < 0)
   {
      ResetLastError();
      if(!ObjectCreate(0, text, OBJ_LABEL, 0, 0, 0))
      {
         PrintFormat("DTC PRO: Footer text creation failed. Error=%d", GetLastError());
         return;
      }
   }

   ObjectSetInteger(0, text, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, text, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, text, OBJPROP_XDISTANCE, footerX + footerW / 2);
   ObjectSetInteger(0, text, OBJPROP_YDISTANCE, footerY + footerH / 2);
   ObjectSetString(0, text, OBJPROP_TEXT,
                   "@Alphentra");
   ObjectSetInteger(0, text, OBJPROP_COLOR, C'255,193,7');
   ObjectSetInteger(0, text, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, text, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, text, OBJPROP_BACK, false);
   ObjectSetInteger(0, text, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, text, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, text, OBJPROP_ZORDER, 1000);

   ChartRedraw(0);
}

void DashboardLabel(string id, int x, int y, string text,
                    color clr, int fontSize, string fontName)
{
   string name = prefix + "DASH_" + id;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, fontName);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

string GetTFTrend(int h20, int h50)
{
   if(h20 == INVALID_HANDLE || h50 == INVALID_HANDLE)
      return "LOADING";

   if(BarsCalculated(h20) < 3 || BarsCalculated(h50) < 3)
      return "LOADING";

   double ema20[1], ema50[1];
   if(CopyBuffer(h20, 0, 1, 1, ema20) != 1 ||
      CopyBuffer(h50, 0, 1, 1, ema50) != 1)
      return "LOADING";

   if(ema20[0] > ema50[0]) return "BULLISH";
   if(ema20[0] < ema50[0]) return "BEARISH";
   return "NEUTRAL";
}
