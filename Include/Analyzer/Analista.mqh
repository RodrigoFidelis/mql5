//+----------------------------------------------------------------------+
//|                                                     Analista.mqh     |
//| COMUNIDADE:                              https://github.com/MQL5     |
//|                                                                      |
//| Copyright (C) 2015  Rodrigo Campos Fidélis                           |
//|                                                                      |  
//| This program is free software: you can redistribute it and/or modify |
//| it under the terms of the GNU General Public License as published by |
//| the Free Software Foundation, either version 3 of the License, or    |
//| (at your option) any later version.                                  |
//|                                                                      |  
//| This program is distributed in the hope that it will be useful,      |
//| but WITHOUT ANY WARRANTY; without even the implied warranty of       |
//| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        |
//| GNU General Public License for more details.                         |
//|                                                                      |
//| You should have received a copy of the GNU General Public License    |  
//| along with this program.  If not, see <http://www.gnu.org/licenses/>.|
//|                                                                      |  
//|//+-------------------------------------------------------------------+

/* 
Função iBandsnarrow() por Rodrigo Campos Fidélis:

Esta função detecta se as Bandas de Bollinger estão estreitas e se abrindo
Para chamar a função defina o básico da Bandas de Bollinger, Periodo, Deslocamento, Desvio Padrão.
Seguido do número de barras do estreitamento (normalmente uso a metade do período)
E de um Percentual exemplo 250, esse valor equivale ao tamanho percentual da média das 
bandas em relação a média do corpo dos candles no período analizado.

*/
bool iBandsnarrow(int ma_period, int ma_shift,double deviation,int number_of_bars, double percent_of_candles)
{
   
   string symbol = Symbol();
   double base_values[];     // indicator buffer of the middle line of Bollinger Bands
   double upper_values[];    // indicator buffer of the upper border
   double lower_values[];    // indicator buffer of the lower border
   int shift=0;               // shift
   bool result=false;
   ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT;
  
  ArraySetAsSeries(base_values,true);
  ArraySetAsSeries(upper_values,true);
  ArraySetAsSeries(lower_values,true);
    
  
  int iBB_Handle = iBands(Symbol(), timeframe,ma_period,0,deviation,PRICE_CLOSE);
  
  int amount = BarsCalculated(iBB_Handle);// number of copied values
//--- fill a part of the MiddleBuffer array with values from the indicator buffer that has 0 index
   if(CopyBuffer(iBB_Handle,0,0,amount,base_values)<0)
     {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the iBands base_values indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
     }
 
//--- fill a part of the UpperBuffer array with values from the indicator buffer that has index 1
   if(CopyBuffer(iBB_Handle,1,0,amount,upper_values)<0) 
     {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the iBands upper_values indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
     }
 
//--- fill a part of the LowerBuffer array with values from the indicator buffer that has index 2
   if(CopyBuffer(iBB_Handle,2,0,amount,lower_values)<0)
     {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the iBands lower_values indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
     }
   double var_percent = 115; // Aqui você coloca a variação mínima da ultima banda com relação a anterior para detectar a expansão.
   double total_bands=0;
   double tamanho_bandas=0;
   double total_candles=0;
   double high=0;
   double low=0;
   ArraySetAsSeries(High,true);
   ArraySetAsSeries(Low,true);
   
   int copied_high =CopyHigh(symbol,timeframe,0,Bars(symbol,timeframe),High);
   int copied_low =CopyLow(symbol,timeframe,0,Bars(symbol,timeframe),Low);
   
   int i=0;
   for(i=0; i<=(number_of_bars); i++)
   {
      
      total_bands = upper_values[i]- lower_values[i] + total_bands;
      
      if(copied_high>0 && i<copied_high) high=High[i];
      if(copied_low>0 && i<copied_low) low=Low[i];
      
      total_candles = High[i] - Low[i]+ total_candles;
    
   }
   
   double average_bands =  (total_bands/i);
   double average_candles = (total_candles/i);
   
   if(
        ((average_bands/average_candles) < (percent_of_candles/100))&&
        ((upper_values[0]-lower_values[0])>((upper_values[1]-lower_values[1])*(var_percent/100)))&&
        ((upper_values[1]-lower_values[1])>(upper_values[2]-lower_values[2]))
     )
      {
         result = true;
      }
   else
      {
         result = false;
      }

   return(result);

}
