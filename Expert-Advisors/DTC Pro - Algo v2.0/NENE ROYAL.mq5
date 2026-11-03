//+------------------------------------------------------------------+
//|                                                      DTC_v1.36.mq5 |
//|                        Converted from Pine Script DTC v1.36       |
//|                        Professional MT5 Version                   |
//+------------------------------------------------------------------+
#property copyright "DTC v1.36 MT5 Conversion"
#property link      ""
#property version   "1.36"
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
input double InpATRMin = 0.5;            // Min ATR Value

input group "=== Dashboard ==="
input bool   InpShowDashboard = true;    // Show Multi-Timeframe Dashboard

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

// Signal state
int signal_state = 0; // 1 = long, -1 = short, 0 = none

// Objects names
string prefix = "DTC_";

// SL lookback length
int sl_length = 8;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
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

   if(handleEMA1 == INVALID_HANDLE || handleEMA2 == INVALID_HANDLE ||
      handleEMA3 == INVALID_HANDLE || handleEMA4 == INVALID_HANDLE ||
      handleEMA5 == INVALID_HANDLE || handleEMA6 == INVALID_HANDLE ||
      handleATR  == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
   }

   // SL lookback
   if(InpSLLookback == "Tiny")  sl_length = 3;
   else if(InpSLLookback == "Small") sl_length = 5;
   else if(InpSLLookback == "Mid")   sl_length = 8;
   else if(InpSLLookback == "Large") sl_length = 12;
   else sl_length = 8;

   IndicatorSetString(INDICATOR_SHORTNAME, "DTC v1.36");
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

   int limit = rates_total - prev_calculated;
   if(prev_calculated > 0) limit++;
   if(limit > rates_total - 50) limit = rates_total - 50;

   // Process from older to newer for proper signal detection
   for(int i = limit; i >= 0; i--)
   {
      // Trend detection
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

      // Color the EMAs (we change plot color dynamically via objects or comment)
      // For simplicity we keep plot colors static and use Comment/Dashboard for trend

      // Previous trend
      bool prev_bullish = false;
      bool prev_bearish = false;
      if(i + 1 < rates_total)
      {
         prev_bullish = (EMA1Buffer[i+1] > EMA2Buffer[i+1] &&
                         EMA2Buffer[i+1] > EMA3Buffer[i+1] &&
                         EMA3Buffer[i+1] > EMA4Buffer[i+1] &&
                         EMA4Buffer[i+1] > EMA5Buffer[i+1] &&
                         EMA5Buffer[i+1] > EMA6Buffer[i+1]);

         prev_bearish = (EMA1Buffer[i+1] < EMA2Buffer[i+1] &&
                         EMA2Buffer[i+1] < EMA3Buffer[i+1] &&
                         EMA3Buffer[i+1] < EMA4Buffer[i+1] &&
                         EMA4Buffer[i+1] < EMA5Buffer[i+1] &&
                         EMA5Buffer[i+1] < EMA6Buffer[i+1]);
      }

      bool long_signal_raw  = (!prev_bullish && bullish);
      bool short_signal_raw = (!prev_bearish && bearish);

      bool atr_ok = true;
      if(InpUseATR)
         atr_ok = (atr[i] > InpATRMin);

      bool long_signal  = long_signal_raw  && (signal_state != 1)  && atr_ok;
      bool short_signal = short_signal_raw && (signal_state != -1) && atr_ok;

      // Only process confirmed signals on closed bars (i > 0) or current forming if needed
      // We process on the most recent closed bar mainly for cleanliness
      if(i == 1) // last closed bar
      {
         if(long_signal)
         {
            signal_state = 1;
            CreateTradeLevels(true, close[i], time[i], atr[i]);
            if(InpShowLabels)
               CreateSignalLabel(true, time[i], low[i] - atr[i]*0.5);
         }
         else if(short_signal)
         {
            signal_state = -1;
            CreateTradeLevels(false, close[i], time[i], atr[i]);
            if(InpShowLabels)
               CreateSignalLabel(false, time[i], high[i] + atr[i]*0.5);
         }
      }
   }

   // Update Dashboard
   if(InpShowDashboard)
      UpdateDashboard();

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
void CreateTradeLevels(bool isLong, double entryPrice, datetime signalTime, double atrVal)
{
   // Delete previous levels
   ObjectsDeleteAll(0, prefix + "LVL_");

   double sl, tp1, tp2, tp3, tp4;

   if(isLong)
   {
      sl  = entryPrice * (1.0 - InpStopLossPct / 100.0);
      tp1 = entryPrice * (1.0 + InpStopLossPct * InpTP1Mult / 100.0);
      tp2 = entryPrice * (1.0 + InpStopLossPct * InpTP2Mult / 100.0);
      tp3 = entryPrice * (1.0 + InpStopLossPct * InpTP3Mult / 100.0);
      tp4 = entryPrice * (1.0 + InpStopLossPct * InpTP4Mult / 100.0);
   }
   else
   {
      sl  = entryPrice * (1.0 + InpStopLossPct / 100.0);
      tp1 = entryPrice * (1.0 - InpStopLossPct * InpTP1Mult / 100.0);
      tp2 = entryPrice * (1.0 - InpStopLossPct * InpTP2Mult / 100.0);
      tp3 = entryPrice * (1.0 - InpStopLossPct * InpTP3Mult / 100.0);
      tp4 = entryPrice * (1.0 - InpStopLossPct * InpTP4Mult / 100.0);
   }

   datetime t1 = signalTime;
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
   string dash = "\n\n===== DTC v1.36 =====\n";
   dash += "15M : " + GetTFTrend(TF1) + "\n";
   dash += "30M : " + GetTFTrend(TF2) + "\n";
   dash += "1H  : " + GetTFTrend(TF3) + "\n";
   dash += "4H  : " + GetTFTrend(TF4) + "\n";
   dash += "D1  : " + GetTFTrend(TF5) + "\n";
   dash += "=====================";

   Comment(dash);
}

//+------------------------------------------------------------------+
//| Get Higher TF Trend (EMA20 vs EMA50)                             |
//+------------------------------------------------------------------+
string GetTFTrend(ENUM_TIMEFRAMES tf)
{
   double ema20[], ema50[];
   ArraySetAsSeries(ema20, true);
   ArraySetAsSeries(ema50, true);

   int h20 = iMA(_Symbol, tf, 20, 0, MODE_EMA, PRICE_CLOSE);
   int h50 = iMA(_Symbol, tf, 50, 0, MODE_EMA, PRICE_CLOSE);

   if(h20 == INVALID_HANDLE || h50 == INVALID_HANDLE)
      return "N/A";

   if(CopyBuffer(h20, 0, 0, 3, ema20) <= 0 || CopyBuffer(h50, 0, 0, 3, ema50) <= 0)
   {
      IndicatorRelease(h20);
      IndicatorRelease(h50);
      return "N/A";
   }

   string result = (ema20[0] > ema50[0]) ? "Bullish" : "Bearish";

   IndicatorRelease(h20);
   IndicatorRelease(h50);

   return result;
}
//+------------------------------------------------------------------+