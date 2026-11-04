//+------------------------------------------------------------------+
//|                    ALPHENTRA | HFT CaR v1.0                    |
//|  Fixed: Pending Limit orders no longer cancelled by broker       |
//+------------------------------------------------------------------+
#property copyright "Copyright © ALPHENTRA | HFT CaR"
#property link      "https://alphentra.ai"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

CTrade         trade;
CPositionInfo  posInfo;
COrderInfo     orderInfo;
CSymbolInfo    symInfo;
CAccountInfo   accInfo;

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

input group "=== RISK ==="
input double   InpMaxDailyLossPct  = 5.0;
input double   InpMaxDrawdownPct   = 12.0;
input double   InpMaxSpreadPoints  = 50;
input ulong    InpMagic            = 20261007;
input int      InpSlippage         = 30;
input bool     InpDebug            = true;

input group "=== DASHBOARD ==="
input bool     InpShowDashboard    = true;
input int      InpDashX            = 15;
input int      InpDashY            = 20;

//--- Globals
int handleFast, handleSlow, handleRSI, handleATR;
ENUM_CAR_STATE g_carState = CAR_IDLE;
double g_carDebt = 0, g_carLot = 0;
int    g_carStep = 0, g_carDir = 0;
datetime g_carTime = 0;
bool   g_lastProfit = true;
double pipValue = 0;
int    g_digits = 0;
double dailyStartEq = 0, peakEquity = 0, startEquity = 0;
bool   tradingEnabled = true;
string statusText = "Ready", lastSignal = "-";
int    lastSignalDir = 0;
datetime pendingPlaceTime = 0;
string prefix = "HCR_";

//+------------------------------------------------------------------+
int OnInit()
{
   if(!symInfo.Name(_Symbol)) return INIT_FAILED;
   symInfo.Refresh();

   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   pipValue = (g_digits == 3 || g_digits == 5) ? _Point * 10.0 : _Point;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   handleFast = iMA(_Symbol, InpTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleSlow = iMA(_Symbol, InpTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleRSI  = iRSI(_Symbol, InpTF, InpRSIPeriod, PRICE_CLOSE);
   handleATR  = iATR(_Symbol, InpTF, 14);

   if(handleFast == INVALID_HANDLE || handleSlow == INVALID_HANDLE || handleATR == INVALID_HANDLE)
   {
      Print("Failed to create indicators");
      return INIT_FAILED;
   }

   startEquity = peakEquity = dailyStartEq = accInfo.Equity();
   EventSetTimer(2);
   if(InpShowDashboard) CreateDashboard();

   Print("v7.10 Fixed Limit Orders – Ready");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   IndicatorRelease(handleFast);
   IndicatorRelease(handleSlow);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleATR);
   ObjectsDeleteAll(0, prefix);
}

void OnTimer()
{
   CheckEquityProtection();
   if(InpShowDashboard) UpdateDashboard();
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Daily reset
   static int lastDay = -1;
   MqlDateTime dt; TimeCurrent(dt);
   if(dt.day != lastDay)
   {
      lastDay = dt.day;
      dailyStartEq = accInfo.Equity();
   }

   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPoints)
   {
      statusText = "Spread high";
      return;
   }

   if(!tradingEnabled) return;

   // CaR core
   CAR_HandleCooldown();
   CAR_Monitor();

   // Manage pending timeout
   ManagePendingTimeout();

   if(g_carState == CAR_IDLE && !HasOurPosition() && !HasPendingOrder())
   {
      int signal = GetSignal();
      if(signal != 0)
      {
         lastSignalDir = signal;
         if(InpUseLimitOrders)
            PlaceLimitEntry(signal);
         else
            CAR_OpenFirst(signal);
      }
   }
}

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

//+------------------------------------------------------------------+
// DASHBOARD
//+------------------------------------------------------------------+
void CreateDashboard()
{
   ObjectCreate(0, prefix+"BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_XDISTANCE, InpDashX);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_YDISTANCE, InpDashY);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_XSIZE, 250);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_YSIZE, 250);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, prefix+"BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);

   CreateLbl(prefix+"T", InpDashX+10, InpDashY+8,  "HFT CaR", clrGold, 10);
   CreateLbl(prefix+"BRAND", InpDashX+10, InpDashY+25, "Powered by ALPHENTRA", clrSilver, 8);
   CreateLbl(prefix+"S", InpDashX+10, InpDashY+45, "Status: Ready", clrWhite, 9);
   CreateLbl(prefix+"C", InpDashX+10, InpDashY+65, "State: IDLE", clrWhite, 9);
   CreateLbl(prefix+"P", InpDashX+10, InpDashY+85, "Step: 0", clrWhite, 9);
   CreateLbl(prefix+"D", InpDashX+10, InpDashY+105, "Debt: $0", clrWhite, 9);
   CreateLbl(prefix+"E", InpDashX+10, InpDashY+125,"Equity: 0", clrWhite, 9);

   ObjectCreate(0, prefix+"BTN_CLOSE", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, prefix+"BTN_CLOSE", OBJPROP_XDISTANCE, InpDashX+10);
   ObjectSetInteger(0, prefix+"BTN_CLOSE", OBJPROP_YDISTANCE, InpDashY+150);
   ObjectSetInteger(0, prefix+"BTN_CLOSE", OBJPROP_XSIZE, 100);
   ObjectSetInteger(0, prefix+"BTN_CLOSE", OBJPROP_YSIZE, 26);
   ObjectSetString(0, prefix+"BTN_CLOSE", OBJPROP_TEXT, "CLOSE ALL");
   ObjectSetInteger(0, prefix+"BTN_CLOSE", OBJPROP_BGCOLOR, clrCrimson);
   ObjectSetInteger(0, prefix+"BTN_CLOSE", OBJPROP_COLOR, clrWhite);

   ObjectCreate(0, prefix+"BTN_PAUSE", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, prefix+"BTN_PAUSE", OBJPROP_XDISTANCE, InpDashX+120);
   ObjectSetInteger(0, prefix+"BTN_PAUSE", OBJPROP_YDISTANCE, InpDashY+150);
   ObjectSetInteger(0, prefix+"BTN_PAUSE", OBJPROP_XSIZE, 100);
   ObjectSetInteger(0, prefix+"BTN_PAUSE", OBJPROP_YSIZE, 26);
   ObjectSetString(0, prefix+"BTN_PAUSE", OBJPROP_TEXT, "PAUSE");
   ObjectSetInteger(0, prefix+"BTN_PAUSE", OBJPROP_BGCOLOR, clrDarkOrange);
   ObjectSetInteger(0, prefix+"BTN_PAUSE", OBJPROP_COLOR, clrWhite);
}

void CreateLbl(string name, int x, int y, string txt, color clr, int size)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void UpdateDashboard()
{
   if(!InpShowDashboard) return;
   string st = "IDLE";
   if(g_carState == CAR_RECOVERING) st = "RECOVERING";
   if(g_carState == CAR_COOLDOWN)   st = "COOLDOWN";

   ObjectSetString(0, prefix+"S", OBJPROP_TEXT, "Status: " + statusText);
   ObjectSetString(0, prefix+"C", OBJPROP_TEXT, "State: " + st);
   ObjectSetString(0, prefix+"P", OBJPROP_TEXT, "Step: " + IntegerToString(g_carStep));
   ObjectSetString(0, prefix+"D", OBJPROP_TEXT, "Debt: $" + DoubleToString(g_carDebt, 2));
   ObjectSetString(0, prefix+"E", OBJPROP_TEXT, "Equity: " + DoubleToString(accInfo.Equity(), 2));
   ObjectSetString(0, prefix+"BTN_PAUSE", OBJPROP_TEXT, tradingEnabled ? "PAUSE" : "RESUME");
   ChartRedraw();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(sparam == prefix+"BTN_CLOSE") { CloseAll(); statusText = "Closed"; }
   if(sparam == prefix+"BTN_PAUSE")
   {
      tradingEnabled = !tradingEnabled;
      statusText = tradingEnabled ? "Resumed" : "Paused";
   }
   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   ChartRedraw();
}
//+------------------------------------------------------------------+