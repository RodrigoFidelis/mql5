//+------------------------------------------------------------------+
//|                                                        MABOL.mq5 |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2010, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"

#include <ExpertAdvisorECN.mqh>

//Bot will need 2 bollinger bands, inner and outer
//It will need a 200 MA to trade only in direction of the trend
//Stop will be the high\low of the previous candle
//First Take profit will be middle band
//Second take profit will be upper\lower band.
//I want the bot to report on how many pips every thing is.
//Inputs needed will be the risk needed, inner bollinger period and dev, outer bollinger period and dev and MA period.
//Can always use SL, TP and TS as 0 and if anything else use that to backtest.

//input int    SL        =  50;     // Stop Loss distance
//input int    TP        = 150;     // Take Profit distance
//input int    TS        =  50;     // Trailing Stop distance
input double Risk       =  0.01;    // Risk
input int    MAper      =  200;     // MA Period for overall direction
input int    OBBPer     =  21;      // Outer Bollinger Bands period
input double OBBDev     =  2;       // Outer Bollinger Bands deviation
input int    IBBPer     =  21;      // Inner Bollinger Bands period
input double IBBDev     =  3;       // Inner Bollinger Bands deviation

//---
class CMyEA : public CExpertAdvisor
  {
protected:
   double            m_risk;           // size of risk
   double               m_sl;             // Stop Loss
   int               m_tp;             // Take Profit
   //int               m_ts;           // Trailing Stop  
   int               m_OBBPer;         // Outer Bollinger Bands p1eriod     
   double            m_OBBDev;         // Outer Bollinger Bands deviation 
   int               m_hObb;           // Outer Bollinger Bands indicator handle     
   int               m_IBBPer;         // Inner Bollinger Bands p1eriod     
   double            m_IBBDev;         // Inner Bollinger Bands deviation 
   int               m_h_Ibb;           // Inner Bollinger Bands indicator handle     
   int               m_MAPer;          // MA Period
   int               m_hMA;            // MA handle
public:
   void              CMyEA();
   void             ~CMyEA();
   virtual bool      Init(string smb,ENUM_TIMEFRAMES tf); // initialization
   virtual bool      Main();                              // main function
   virtual void      OpenPosition(long dir);              // open position on signal
   virtual void      ClosePosition(long dir);             // close position on signal
   virtual long      CheckSignal(bool bEntry);            // check signal
   virtual double      getSL(bool Dir);
  };

//------------------------------------------------------------------    CMyEA
void CMyEA::CMyEA() { }

//------------------------------------------------------------------    ~CMyEA
void CMyEA::~CMyEA()
{
   IndicatorRelease(m_hMA);   // delete indicators
   IndicatorRelease(m_hObb);
   IndicatorRelease(m_h_Ibb);
   
}

//------------------------------------------------------------------    Init
bool CMyEA::Init(string smb,ENUM_TIMEFRAMES tf)
{
   if(!CExpertAdvisor::Init(0,smb,tf)) return(false);                                // initialize parent class

   //copy parameters
   m_OBBPer = OBBPer; 
   m_OBBDev = OBBDev;
   m_IBBPer = IBBPer; 
   m_IBBDev = IBBDev;
   m_MAPer  = MAper;
   m_risk   = Risk;
   ////////////HARD CODED///////////////
   m_h_Ibb=iBands(m_smb,m_tf,21,0,2,PRICE_CLOSE); 
   m_hObb=iBands(m_smb,m_tf,21,0,3,PRICE_CLOSE); 
   //m_hObb=iCustom(m_smb,m_tf,"myBB",21,0,3,PRICE_CLOSE); 
   /////////////////////////////////////
   m_hMA=iMA(m_smb,m_tf, m_MAPer, 0, MODE_EMA ,PRICE_CLOSE);

                                  
   m_bInit=true; 
   return(true);                                                                     // trade allowed
}


//------------------------------------------------------------------    Main
bool CMyEA::Main() // main function
{
   if(!CExpertAdvisor::Main()) return(false); // call function of parent class
   if(Bars(m_smb,m_tf)<=100) return(false);   // if there are insufficient number of bars
   if(!CheckNewBar()) return(true);           // check new bar
                                                
   long dir;                                  // check each direction
   dir=ORDER_TYPE_BUY;
   OpenPosition(dir); ClosePosition(dir);    //TrailingPosition(dir,m_ts);
   dir=ORDER_TYPE_SELL;
   OpenPosition(dir); ClosePosition(dir);    //TrailingPosition(dir,m_ts);
   return(true);
}

//------------------------------------------------------------------    OpenPos
void CMyEA::OpenPosition(long dir)
{
// if there is an order, then exit
   if(PositionSelect(m_smb)) return;
// if there is no signal for current direction
   if(dir!=CheckSignal(true)) return;
   
   //Print("m_tp :: " + m_tp);
   //Print("m_slll :: " + m_sl);
   //Print("m_risk :: " + m_risk);
   
   double lot=CountLotByRisk(m_sl,m_risk,0);
   
   //Print("lot :: " + lot);
   
// if lot is not defined
   if(lot<=0) return;
// open position
   DealOpen(dir,lot,m_sl,m_tp);
}


//------------------------------------------------------------------    ClosePos
void CMyEA::ClosePosition(long dir)
{
// if there is no position, then exit
   if(!PositionSelect(m_smb)) return;
// if position of unchecked direction
   if(dir!=PositionGetInteger(POSITION_TYPE)) return;
// if the close signal didn't match the current position
   if(dir!=CheckSignal(false)) return;
// close position
   m_trade.PositionClose(m_smb,1);
}


//------------------------------------------------------------------    CheckSignal
long CMyEA::CheckSignal(bool bEntry)
{
  
   double ma[3],
          O_bbup[3],   // Array of Bollinger Bands' upper border values
          O_bbdn[3],   // Array of Bollinger Bands' lower border values
          I_bbup[3],   // Array of Bollinger Bands' upper border values
          I_bbdn[3],   // Array of Bollinger Bands' lower border values
          I_bbmid[3];  // Array of Bollinger Bands' lower border values
   
   MqlRates rt[4];   // Array of price values of last 3 bars
   
   if(CopyRates(m_smb, m_tf,0,4,rt)!=4) // Copy price values of last 3 bars to array
     { Print("CopyRates ",m_smb," history is not loaded"); return(WRONG_VALUE); }
   
   // Copy indicator values to array -- 2nd param = indicators buffers -- 1 = upperband -- 2 = lower -- 0= mid
   //                                -- 3rd param = start element, 0 = current bar, 
   //                                -- 4th param = number of elemnts to copy)
   // Array values:  -- rt[0].close) -- Oldest Bar and rt.3.close is the cusrrent Bar
   if(CopyBuffer(m_hObb,1,0,3,O_bbup)<3 || CopyBuffer(m_hObb,2,0,3,O_bbdn)<3 || CopyBuffer(m_h_Ibb,1,0,3,I_bbup)<3
      || CopyBuffer(m_h_Ibb,0,0,3,I_bbmid)<3 || CopyBuffer(m_hObb,2,0,3,O_bbdn)<3  || CopyBuffer(m_hMA,0,0,3,ma)<3
      || CopyBuffer(m_h_Ibb,2,0,3,I_bbdn)<3)
   { 
      Print("CopyBuffer - no data"); 
      return(WRONG_VALUE); 
   }
     
    //Print("rt1.close: " + rt[1].close);
    //Print("rt2.open: " + rt[2].open);
    //Print("rt2.close: " + rt[2].close);
    //Print("I_bbup[0]: " + I_bbup[0]);
    //Print("O_bbup[0]: " + O_bbup[0]);
    //Print("ma1: " + ma[1]);
   
   //Buy if price closes below the inner lower band but is inside the outer and the nex candle is a reverse candle 
   //and in same direction as the MA or trend.
   if(rt[1].close<I_bbdn[0] && 
      rt[1].close>O_bbdn[0] && 
      rt[2].open < rt[2].close && 
      rt[1].close > ma[1] 
      )
   {
      //m_sl = 15;
      m_tp = 30;
      double sl = getSL(true); //Gets the higesth high\low of the last 4 candles to use that price as a stop
      double StopLvl=m_smbinf.StopsLevel()*m_smbinf.Point(); // remember stop level
      //m_sl = ((sl + rt[3].open) + StopLvl) * m_smbinf.Point();  //Problem is that it's 0.00018 is not an int neither is stop level
      //m_sl = sl + rt[3].open / 100000;
      m_sl = NormalizeDouble(sl + rt[3].open,5) *10000; 

      Print("BUY==========================");
      Print("sl: " + (string)sl);
      Print("m_sl: "+ (string)m_sl);
      Print("rt[3].open: " +  rt[3].open);
      Print("Stoplvl: " + (string)StopLvl);
      Print("==========================");
      

      //m_tp = (I_bbmid[1] - rt[2].close) / 0.0001;
      //Print("m_tp: " + m_tp);
      //Print("I_bbmid[1] : " + I_bbmid[1]);
      //Print("rt[2].close : " + rt[2].close);
      //|| rt[3].close == I_bbmid[1]
      return(bEntry ? ORDER_TYPE_BUY:ORDER_TYPE_SELL); // condition for buy   
   }
 
 
 
   //Sell if the close breaks through the lowerband and ADX high  
   //if(rt[1].open>bbdn[1] && rt[1].close<bbdn[1] && adx[1] > MaxADX)
   if(rt[1].close>I_bbup[0] && 
      rt[1].close<O_bbup[0] && 
      rt[2].open > rt[2].close && 
      rt[1].close < ma[1] 
      )
   {
      
      //m_sl = 30;
      m_tp = 30;
      
      double sl = getSL(true);   //Gets the lowest low of the last 4 candles to use that price as a stop
      double StopLvl=m_smbinf.StopsLevel()*m_smbinf.Point(); // remember stop level
      //m_sl = ((sl - rt[3].open) + StopLvl) * m_smbinf.Point();   
      m_sl = NormalizeDouble(sl - rt[3].open,5) *10000; 
      Print("SELL==========================");
      Print("rt3: " + rt[3].open);
      Print("Stoplvl: " + (string)StopLvl);
      Print("sl: " + NormalizeDouble(sl,5));
      Print("m_sl: "+ m_sl);
      Print("==========================");
      
      
      //m_sl = (rt[1].high - rt[3].open)
      //m_tp = (rt[2].close - I_bbmid[1]) / 0.0001;
      //Print("==========================");
      //Print("m_tp: " + m_tp);
      //Print("I_bbmid[1] : " + I_bbmid[1]);
      //Print("rt[2].close : " + rt[2].close);
      //Print("==========================");
      
      //|| rt[1].close > I_bbmid[1]
      return(bEntry ? ORDER_TYPE_SELL:ORDER_TYPE_BUY); // condition for selll
   }

   return(WRONG_VALUE); // if there is no signal
}

CMyEA ea; // class instance



//Gets the higesth high of the last 4 candles to use that price as a stop
double CMyEA::getSL(bool dir) 
{
   MqlRates rt[4];   // Array of price values of last 3 bars
   double sl;
   
   if(CopyRates(m_smb, m_tf,0,4,rt)!=4) // Copy price values of last 3 bars to array
   { 
      Print("CopyRates ",m_smb," history is not loaded"); return(WRONG_VALUE); 
   }
   
   if(dir)
   {
      //THis will work for sell but not buy    
      sl = rt[0].high;
      for(int i = 0; i <4; i++)
      {
         //Print("rt[i].high:: " + i + " :: " + rt[i].high);
      
         if(rt[i].high > sl)
         {
            sl = rt[i].high;
         }
      }
   }
   else
   {
      //For buy you would need the low
      sl = rt[0].low;
      for(int i=0; 1<4; i++)
      {
         //Print("rt[i].low:: " + i + " :: " + rt[i].low);  
               
         if(rt[i].low < sl)
         {
            sl = rt[i].low;
         }
      }
   }

   return sl;
}



//------------------------------------------------------------------    OnInit
int OnInit()
{
   ea.Init(Symbol(),Period()); // initialize expert

                                 // initialization example
   // ea.Init(Symbol(), PERIOD_M5); // for fixed timeframe
   // ea.Init("USDJPY", PERIOD_H2); // for fixed symbol and timeframe

   return(0);
}

//------------------------------------------------------------------    OnDeinit
void OnDeinit(const int reason) { }

//------------------------------------------------------------------    OnTick
void OnTick()
{
   ea.Main(); // process incoming tick
}
//+------------------------------------------------------------------+
