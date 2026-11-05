//+------------------------------------------------------------------+
//|                                                                  |
//|                                                                  |
//|                                                                  |
//|                    A L P H E N T R A   A I                       |
//|                                                                  |
//|                     TRADE BEYOND LIMITS.                         |
//|                                                                  |
//|                         EA TEMPLATE                              |
//|  --------------------------------------------------------------  |
//|                                                                  |
//|  PRODUCT  : EA TEMPLATE                                          |
//|  DEVELOPER: ALPHENTRA AI                                         |
//|  ENGINE   : EA TEMPLATE ENGINE                                   |
//|                                                                  |
//|  FEATURES  : EA TEMPLATE FEATURES                                |
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
#property version   "1.0"
#property strict
#property description "Dynamic Dashboard Template"

input group "=== ALPHENTRA DISPLAY ==="
input bool InpShowDashboard = true;
input bool InpShowBrandFooter = true;
input int  InpDashboardX = 12;
input int  InpDashboardY = 22;

input group "=== DASHBOARD DEMO VALUES ==="
input string InpDemoSignal = "WAITING";
input string InpDemoStatus = "READY - DEMO";

const color C_BG    = C'5,5,5';
const color C_GOLD  = C'255,193,7';
const color C_GREEN = C'0,220,100';
const color C_RED   = C'255,75,75';
const color C_MUTED = C'165,165,165';
const color C_WHITE = C'235,235,235';
const color C_PANEL = C'8,8,8';

const string PREFIX = "ALPHENTRA_DUMMY_EA_";

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

   string title="DUMMY EA";
   string subtitle=_Symbol+"  |  "+EnumToString(_Period);

   string rows[7];
   color rowColors[7];
   int rowFonts[7];

   rows[0]="SIGNAL: "+InpDemoSignal;
   rows[1]="ENTRY: --";
   rows[2]="STOP LOSS: --";
   rows[3]="TP1 - 1:1: --";
   rows[4]="TP2 - 1:2: --";
   rows[5]="TP3 - 1:3: --";
   rows[6]="STATUS: "+InpDemoStatus;

   rowColors[0]=(InpDemoSignal=="BUY" ? C_GREEN :
                 (InpDemoSignal=="SELL" ? C_RED : C_GOLD));
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
   ChartRedraw(0);
}

int OnInit()
{
   EventSetTimer(1);
   UpdateTemplateVisuals();
   Print("DUMMY EA initialized. Dashboard is display-only; no trading logic.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0,PREFIX);
   ChartRedraw(0);
}

void OnTick()
{
   // DUMMY EA: intentionally no orders or trading actions.
}

void OnTimer()
{
   UpdateTemplateVisuals();
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
      UpdateTemplateVisuals();
}
//+------------------------------------------------------------------+
