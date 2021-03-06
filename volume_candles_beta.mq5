//+------------------------------------------------------------------+
//|                                            volume_candles.mq5 |
//|                                                    Ismael Barros |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Ismael de Sousa Barros"
#property link      "https://www.mql5.com"
#property version   "14.0"

#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

input double numContract      = 3;        // Quantidade de Contratos
input double SL               = 100.0;    // StopLoss
input double TP               = 150.0;    // TakeProfit

input double gatilhoBE        = 50.0;     // Gatilho Breakeven
input double gatilhoTS        = 100.0;    // Gatilho trailing Stop
input double stepTS           = 50.0;     // Trailing Stop para primeira parcial
input double target1          = 50.0;     // Qtd de pontos Target 1
input double numContractTg1   = 1;        // Qtd de contratos Target 1
input double target2          = 100.0;    // Qtd de pontos Target 2
input double numContractTg2   = 1;        // Qtd de contratos Target 2

//Stop em Reais R$
input double stop_diario      = -150.0;   // Stop Global Diário em R$

input string inicio           = "09:00";  // Horario de Inicio
input string termino          = "17:00";  // Horário de Termino
input string fechamento       = "17:30";  // Horario de Fechamento
input ulong  desvPts          = 30;       // Desvio
input ulong  magicNum         = 123458;   // Magic number

double ema[],volumeTicks[];
int handleEMA,handleVolume;

double PRC,STL,TKP;

double saldo_inicial, capitalLiquido_inicial;

bool beAtivo;
bool parcial_1_Ativo,parcial_2_Ativo,parcial_3_Ativo;

datetime barITraded;

MqlDateTime horario_inicio, horario_termino, horario_fechamento, horario_atual, tempo_expira,bar_atual,bar_order,bar_parcial_3;
MqlRates rates[];
MqlTick ultimo_tick;

CTrade trade;
CSymbolInfo simbolo;

int OnInit()
{
  
  if(!simbolo.Name(_Symbol))
  {
   Print("Ativo invalido");
   return INIT_FAILED;
  }
  
  saldo_inicial = AccountInfoDouble(ACCOUNT_BALANCE);
  capitalLiquido_inicial = AccountInfoDouble(ACCOUNT_EQUITY);
  
  ArraySetAsSeries(ema,true);
  ArraySetAsSeries(volumeTicks,true);
  ArraySetAsSeries(rates,true);
  
  handleEMA = iMA(_Symbol,_Period,21,0,MODE_EMA,PRICE_CLOSE);
  handleVolume = iVolumes(_Symbol,_Period,VOLUME_TICK);
    
   
   if(handleEMA == INVALID_HANDLE || handleVolume == INVALID_HANDLE  )
      {
         Print("Erro na criação dos manipuladores ");
         return INIT_FAILED;
      }
      
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetDeviationInPoints(desvPts);
   trade.SetExpertMagicNumber(magicNum);
   
   TimeToStruct(StringToTime(inicio),horario_inicio);
   TimeToStruct(StringToTime(termino),horario_termino);
   TimeToStruct(StringToTime(fechamento),horario_fechamento);
   
   if(horario_inicio.hour > horario_termino.hour || (horario_inicio.hour == horario_termino.hour && horario_inicio.min >= horario_termino.min))
   {
      printf("Parametros de horario inválidos");
     return(INIT_FAILED); 
   }   
   if(horario_termino.hour > horario_fechamento.hour || (horario_termino.hour == horario_fechamento.hour && horario_termino.min >= horario_fechamento.min))
   {
      printf("Parametros de horario inválidos");
     return(INIT_FAILED); 
   }
            
   return(INIT_SUCCEEDED); 

}
  
void OnDeinit(const int reason)
  {
   printf("Deinit reason : %d",reason);
   
  }

void OnTick()
  {  
   if(!simbolo.RefreshRates())
   {
     return;
   }
   
   if(!SymbolInfoTick(_Symbol,ultimo_tick))
   {
      Print("Erro ao obter preço do ativo ",GetLastError());
      return;
   }
     
   CopyBuffer(handleEMA,0,0,13,ema);
   CopyBuffer(handleVolume,0,0,13,volumeTicks);
   CopyRates(_Symbol,_Period,0,13,rates);
        
   if(HorarioEntrada())
   {
   
      if(Tem_Saldo(saldo_inicial,capitalLiquido_inicial))
      {
         if(!SemPosicao())
         {
            if(!beAtivo)
            {
               Breakeven(ultimo_tick.last);
            }else if(beAtivo)
            {
               TrailingStop(ultimo_tick.last);
               
               if(parcial_1_Ativo == false && parcial_2_Ativo == false)
               {
                  Parcial(ultimo_tick.last,numContractTg1, target1, numContractTg2, target2);
               }
               if(parcial_1_Ativo == true && parcial_2_Ativo == false)
               {
                  Parcial(ultimo_tick.last,numContractTg1, target1, numContractTg2, target2);
               }
            }
            
         }
          
          if(!SemOrdem())
          {
            TimeToStruct(TimeCurrent(),bar_atual);
            TimeToStruct(barITraded,bar_order);
                            
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT)
            {
               if(bar_atual.hour > bar_order.hour || bar_atual.min > bar_order.min)
               {
                  CancelOrder();
               }
               if(ultimo_tick.last > (rates[1].high+50.0))
               {
                     CancelOrder();
               }
             }else if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT)
               {
                  if(bar_atual.hour > bar_order.hour || bar_atual.min > bar_order.min)
                  {
                     CancelOrder();
                  }
                  if(ultimo_tick.last < (rates[1].low-50.0))
                  {
                        CancelOrder();
                  }   
               }
            }
            
            // Verifica se não há nenhuma posição ou ordem em aberto
            if(SemPosicao() && SemOrdem())
            {
               int resultado_sinal_1 = Sinal_1();
               int resultado_sinal_2 = Sinal_2();
               int resultado_sinal_3 = Sinal_3();
               int resultado_sinal_4 = Sinal_4();
               int resultado_sinal_5 = Sinal_5();
               int resultado_sinal_6 = Sinal_6();
               parcial_1_Ativo = false;
               parcial_2_Ativo = false;
               beAtivo = false;
               
               TimeToStruct(TimeCurrent(),bar_atual);
               TimeToStruct(barITraded,bar_order);
               TimeToStruct(rates[0].time,bar_parcial_3);
               
               if(resultado_sinal_1 == 1)
               {
                  //Esta condição evita multiplos trades no mesmo candle
                  if(bar_atual.min != bar_order.min)
                  {
                     //condicão para limit orders
                     if( ultimo_tick.ask > rates[1].high && ultimo_tick.ask < (rates[1].high+50.0))
                        BuyLimit();
                        
                        ObjectCreate(0,"Estrategia_1_Buy",OBJ_ARROW_UP,0,TimeCurrent(),rates[1].low);
                        ObjectSetInteger(0,"Estrategia_1_Buy",OBJPROP_COLOR,clrGreen); 
                        ObjectSetInteger(0,"Estrategia_1_Buy",OBJPROP_WIDTH,10);
                  }
               }else if(resultado_sinal_2 == 1)
               {
                  //Esta condição evita multiplos trades no mesmo candle
                  if(bar_atual.min != bar_order.min)
                  {
                     //compra a mercado
                     BuyMarket();
                     
                     ObjectCreate(0,"Estrategia_2_Buy",OBJ_ARROW_UP,0,TimeCurrent(),rates[1].low);
                     ObjectSetInteger(0,"Estrategia_2_Buy",OBJPROP_COLOR,clrYellow); 
                     ObjectSetInteger(0,"Estrategia_2_Buy",OBJPROP_WIDTH,10);                  
                  }
               }else if(resultado_sinal_3 == 1)
               {
                  //Esta condição evita multiplos trades no mesmo candle
                  if(bar_atual.min != bar_order.min)
                  {
                     BuyMarket();
                     
                     ObjectCreate(0,"Estrategia_3_Buy",OBJ_ARROW_UP,0,TimeCurrent(),rates[1].low);
                     ObjectSetInteger(0,"Estrategia_3_Buy",OBJPROP_COLOR,clrRed); 
                     ObjectSetInteger(0,"Estrategia_3_Buy",OBJPROP_WIDTH,10);
                  }
               }else if(resultado_sinal_4 == 1)
               {
                  //Esta condição evita multiplos trades no mesmo candle
                  if(bar_atual.min != bar_order.min)
                  {
                     BuyMarket();
                     
                     ObjectCreate(0,"Estrategia_4_Buy",OBJ_ARROW_UP,0,TimeCurrent(),rates[1].low);
                     ObjectSetInteger(0,"Estrategia_4_Buy",OBJPROP_COLOR,clrBlue); 
                     ObjectSetInteger(0,"Estrategia_4_Buy",OBJPROP_WIDTH,10);
                  }
               }else if(resultado_sinal_5 == 1)
               {
                  //Esta condição evita multiplos trades no mesmo candle
                  if(bar_atual.min != bar_order.min)
                  {
                     BuyMarket();
                     
                     ObjectCreate(0,"Estrategia_5_Buy",OBJ_ARROW_UP,0,TimeCurrent(),rates[1].low);
                     ObjectSetInteger(0,"Estrategia_5_Buy",OBJPROP_COLOR,clrOrange); 
                     ObjectSetInteger(0,"Estrategia_5_Buy",OBJPROP_WIDTH,10);
                  }
               }else if(resultado_sinal_6 == 1)
               {
                  //Esta condição evita multiplos trades no mesmo candle
                  if(bar_atual.min != bar_order.min)
                  {
                     BuyMarket();
                     
                     ObjectCreate(0,"Estrategia_6_Buy",OBJ_ARROW_UP,0,TimeCurrent(),rates[1].low);
                     ObjectSetInteger(0,"Estrategia_6_Buy",OBJPROP_COLOR,clrMagenta); 
                     ObjectSetInteger(0,"Estrategia_6_Buy",OBJPROP_WIDTH,10);
                  }
               }
               
               if(resultado_sinal_1 == -1)
               {
                  TimeToStruct(TimeCurrent(),bar_atual);
                  TimeToStruct(barITraded,bar_order);
                  
                  //Esta condição evita multiplos trades no mesmo candle
                  if(bar_atual.min != bar_order.min)
                  {
                     //condicão para limit orders
                     if( ultimo_tick.bid < rates[1].low && ultimo_tick.bid > (rates[1].low-50.0))
                        SellLimit();
                        
                        ObjectCreate(0,"Estrategia_1_Sell",OBJ_ARROW_DOWN,0,TimeCurrent(),rates[1].high);
                        ObjectSetInteger(0,"Estrategia_1_Sell",OBJPROP_COLOR,clrGreen);
                        ObjectSetInteger(0,"Estrategia_1_Sell",OBJPROP_WIDTH,10);                                   
                  }
               }else if(resultado_sinal_2 == -1)
               {
                  TimeToStruct(TimeCurrent(),bar_atual);
                  TimeToStruct(barITraded,bar_order);
                  
                  //Esta condição evita multiplos trades no mesmo candle
                  if(bar_atual.min != bar_order.min)
                  {
                     //compra a mercado
                     SellMarket();
                     
                     ObjectCreate(0,"Estrategia_2_Sell",OBJ_ARROW_DOWN,0,TimeCurrent(),rates[1].high);
                     ObjectSetInteger(0,"Estrategia_2_Sell",OBJPROP_COLOR,clrYellow);
                     ObjectSetInteger(0,"Estrategia_2_Sell",OBJPROP_WIDTH,10);                                   
                  }
               }else if(resultado_sinal_3 == -1)
               {
                  TimeToStruct(TimeCurrent(),bar_atual);
                  TimeToStruct(barITraded,bar_order);
                  
                  //Esta condição evita multiplos trades no mesmo candle
                  if(bar_atual.min != bar_order.min)
                  {
                     SellMarket();
                     
                     ObjectCreate(0,"Estrategia_3_Sell",OBJ_ARROW_DOWN,0,TimeCurrent(),rates[1].high);
                     ObjectSetInteger(0,"Estrategia_3_Sell",OBJPROP_COLOR,clrRed);
                     ObjectSetInteger(0,"Estrategia_3_Sell",OBJPROP_WIDTH,10); 
                  }
               }else if(resultado_sinal_4 == -1)
               {
                  TimeToStruct(TimeCurrent(),bar_atual);
                  TimeToStruct(barITraded,bar_order);
                  
                  //Esta condição evita multiplos trades no mesmo candle
                  if(bar_atual.min != bar_order.min)
                  {
                     SellMarket();
                     
                     ObjectCreate(0,"Estrategia_4_Sell",OBJ_ARROW_DOWN,0,TimeCurrent(),rates[1].high);
                     ObjectSetInteger(0,"Estrategia_4_Sell",OBJPROP_COLOR,clrBlue);
                     ObjectSetInteger(0,"Estrategia_4_Sell",OBJPROP_WIDTH,10); 
                  }
               }else if(resultado_sinal_5 == -1)
               {
                  TimeToStruct(TimeCurrent(),bar_atual);
                  TimeToStruct(barITraded,bar_order);
                  
                  //Esta condição evita multiplos trades no mesmo candle
                  if(bar_atual.min != bar_order.min)
                  {
                     SellMarket();
                     
                     ObjectCreate(0,"Estrategia_5_Sell",OBJ_ARROW_DOWN,0,TimeCurrent(),rates[1].high);
                     ObjectSetInteger(0,"Estrategia_5_Sell",OBJPROP_COLOR,clrOrange);
                     ObjectSetInteger(0,"Estrategia_5_Sell",OBJPROP_WIDTH,10); 
                  }
               }else if(resultado_sinal_6 == -1)
               {
                  TimeToStruct(TimeCurrent(),bar_atual);
                  TimeToStruct(barITraded,bar_order);
                  
                  //Esta condição evita multiplos trades no mesmo candle
                  if(bar_atual.min != bar_order.min)
                  {
                     SellMarket();
                     
                     ObjectCreate(0,"Estrategia_6_Sell",OBJ_ARROW_DOWN,0,TimeCurrent(),rates[1].high);
                     ObjectSetInteger(0,"Estrategia_6_Sell",OBJPROP_COLOR,clrMagenta);
                     ObjectSetInteger(0,"Estrategia_6_Sell",OBJPROP_WIDTH,10); 
                  }
               }
             }
        }     
   }
            
   if(HorarioFechamento())
   {
      if(!SemPosicao())
      {
         Fechar();
      }
   }
 }
 
bool HorarioEntrada()
{
   TimeToStruct(TimeCurrent(), horario_atual);
      
      if((horario_atual.hour >= horario_inicio.hour) && (horario_atual.hour <= horario_termino.hour))
      {
            
         if(horario_atual.hour == horario_inicio.hour)
         {
            if(horario_atual.min >= horario_inicio.min)
            {
               return true;            
            }
            else
               return false;
          }       
          if(horario_atual.hour == horario_termino.hour)
          {
            if(horario_atual.min <= horario_termino.min)
            {
               return true;            
            }
            else
               return false;
          }         
        return true;         
      } 
        
    return false;
}
   
bool HorarioFechamento()
{
   TimeToStruct(TimeCurrent(),horario_atual);
   
   if((horario_atual.hour >= horario_termino.hour) && (horario_atual.hour <= horario_fechamento.hour))
   {
      if((horario_atual.min) >= horario_termino.min && (horario_atual.min <= horario_fechamento.min))
      {
         return true;
      }
   }else
      return false; 

   return false;
}

bool SemPosicao()
{
   return !PositionSelect(_Symbol);
}

bool SemOrdem()
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
     OrderGetTicket(i);
     if(OrderGetString(ORDER_SYMBOL)== _Symbol)
     {
         return false;
     }
   }
   
   return true;
}

void Fechar()
{
   if(!PositionSelect(_Symbol))
   {
      return;
   }
   long tipo = PositionGetInteger(POSITION_TYPE);
      
      if(!parcial_1_Ativo)
      {
      
         if(tipo == POSITION_TYPE_BUY){
            trade.Sell(numContract,NULL,0,0,0,"Fechamento ninja EA");
         }
         else
            trade.Buy(numContract,NULL,0,0,0,"Fechamento ninja EA");
      }
      if(parcial_1_Ativo && !parcial_2_Ativo)
      {
      
         if(tipo == POSITION_TYPE_BUY){
            trade.Sell(numContract-numContractTg1,NULL,0,0,0,"Fechamento ninja EA");
         }
         else
            trade.Buy(numContract-numContractTg1,NULL,0,0,0,"Fechamento ninja EA");
      }
      if(parcial_2_Ativo)
      {
      
         if(tipo == POSITION_TYPE_BUY){
            trade.Sell(numContract-numContractTg1-numContractTg2,NULL,0,0,0,"Fechamento ninja EA");
         }
         else
            trade.Buy(numContract-numContractTg1-numContractTg2,NULL,0,0,0,"Fechamento ninja EA");
      }
}
//Estrategia 1  
bool Bullish() 
   {
      double rabicho_cima = rates[1].high - rates[1].close;
      double rabicho_baixo = rates[1].open - rates[1].low;
      
      //Verifica se é bullish bar         
      if(rates[1].close > rates[1].open)
      {
         if(rates[1].open > rates[1].low)
         {
            if((rabicho_cima <= 15.0))
            {
               if(rabicho_baixo >= rabicho_cima+20.0)
               {
                  return true;
               }else
                  return false;
               
            }else
               return false;
         }else
            return false;
      }
      return false;  
   }
//Estrategia 1  
bool Bearish() 
   {
      double rabicho_cima = rates[1].high - rates[1].open;
      double rabicho_baixo = rates[1].close - rates[1].low;
      
      //Verifica se é bearish bar
      if(rates[1].close < rates[1].open)
      {
         if(rates[1].open < rates[1].high)
         {
            if(rabicho_baixo <= 15.0)
            {
               if(rabicho_cima >= rabicho_baixo+20.0)
               {
                  return true;
               }else 
                  return false;
            }else 
               return false;
         }else 
            return false;
      }
      return false;  
   }
//Estrategia 2   
bool Bullish_2() 
   {
      double rabicho_cima = rates[1].high - rates[1].close;
      double rabicho_baixo = rates[1].open - rates[1].low;
      double corpo = rates[1].close - rates[1].open;
      
      //Verifica se é bullish bar         
      if(rates[1].close > rates[1].open)
      {
         if(corpo > 80.0)
         {
            if(rabicho_cima < corpo)
            {
               return true;
            }
         }else
            return false;
         
      }else
         return false;
         
      return false;  
   }
//Estrategia 2  
bool Bearish_2() 
   {
      double rabicho_cima = rates[1].high - rates[1].open;
      double rabicho_baixo = rates[1].close - rates[1].low;
      double corpo = rates[1].open - rates[1].close;
      
      //Verifica se é bearish bar
      if(rates[1].close < rates[1].open)
      {
         if(corpo > 80.0)
         {
            if(rabicho_baixo < corpo)
            {
               return true;
            }
         }else
            return false;
      }else
         return false;
         
      return false;  
   }
   
//Estrategia 3
bool Bullish_3() 
   {
      double rabicho_cima = rates[1].high - rates[1].close;
      double rabicho_baixo = rates[1].open - rates[1].low;
      double corpo = rates[1].close - rates[1].open;
      
      //Verifica se é bullish bar         
      if(rates[1].close > rates[1].open)
      {
         if(corpo > 60.0 && corpo > rabicho_cima && rabicho_cima < 100.0)
         {
            return true;
         }else
            return false;
         
      }else
         return false;
         
      return false;  
   }
//Estrategia 3  
bool Bearish_3() 
   {
      double rabicho_cima = rates[1].high - rates[1].open;
      double rabicho_baixo = rates[1].close - rates[1].low;
      double corpo = rates[1].open - rates[1].close;
      
      //Verifica se é bearish bar
      if(rates[1].close < rates[1].open)
      {
         if(corpo > 60.0 && corpo > rabicho_baixo && rabicho_baixo < 100.0)
         {
            return true;   
         }else
            return false;
      }else
         return false;
         
      return false;  
   }

//Estrategia 4
bool Bullish_4() 
   {
      double rabicho_cima = rates[1].high - rates[1].close;
      double rabicho_baixo = rates[1].open - rates[1].low;
      double corpo = rates[1].close - rates[1].open;
      
      //Verifica se é bullish bar         
      if(rates[1].close > rates[1].open)
      {
         if(corpo >= 60.0 && corpo > rabicho_cima && rabicho_cima <= 20.0 && rabicho_baixo <= 20.0)
         {
            return true;
         }else
            return false;
         
      }else
         return false;
         
      return false;  
   }
//Estrategia 4  
bool Bearish_4() 
   {
      double rabicho_cima = rates[1].high - rates[1].open;
      double rabicho_baixo = rates[1].close - rates[1].low;
      double corpo = rates[1].open - rates[1].close;
      
      //Verifica se é bearish bar
      if(rates[1].close < rates[1].open)
      {
         if(corpo >= 60.0 && corpo > rabicho_baixo && rabicho_baixo < 20.0 && rabicho_baixo <= 20.0)
         {
            return true;   
         }else
            return false;
      }else
         return false;
         
      return false;  
   }
   
//Estrategia 5   
bool Bullish_5() 
   {
      double rabicho_cima = rates[1].high - rates[1].close;
      double rabicho_baixo = rates[1].open - rates[1].low;
      double corpo = rates[1].close - rates[1].open;
      
      //Verifica se é bullish bar         
      if(rates[1].close > rates[1].open)
      {
         if(corpo >= 80.0)
         {
            if(rabicho_cima < corpo)
            {
               return true;
            }
         }else
            return false;
         
      }else
         return false;
         
      return false;  
   }
//Estrategia 5  
bool Bearish_5() 
   {
      double rabicho_cima = rates[1].high - rates[1].open;
      double rabicho_baixo = rates[1].close - rates[1].low;
      double corpo = rates[1].open - rates[1].close;
      
      //Verifica se é bearish bar
      if(rates[1].close < rates[1].open)
      {
         if(corpo >= 80.0)
         {
            if(rabicho_baixo < corpo)
            {
               return true;
            }
         }else
            return false;
      }else
         return false;
         
      return false;  
   }
   
//Estrategia 6   
bool Bullish_6() 
   {
      double rabicho_cima = rates[1].high - rates[1].close;
      double rabicho_baixo = rates[1].open - rates[1].low;
      double corpo = rates[1].close - rates[1].open;
      
      //Verifica se é bullish bar         
      if(rates[1].close > rates[1].open)
      {
         if(corpo >= 80.0)
         {
            if(rabicho_cima < corpo)
            {
               return true;
            }
         }else
            return false;
         
      }else
         return false;
         
      return false;  
   }
//Estrategia 6  
bool Bearish_6() 
   {
      double rabicho_cima = rates[1].high - rates[1].open;
      double rabicho_baixo = rates[1].close - rates[1].low;
      double corpo = rates[1].open - rates[1].close;
      
      //Verifica se é bearish bar
      if(rates[1].close < rates[1].open)
      {
         if(corpo >= 80.0)
         {
            if(rabicho_baixo < corpo)
            {
               return true;
            }
         }else
            return false;
      }else
         return false;
         
      return false;  
   }
   
//Estrategia 1 : Candles Bullish/Bearish tipo martelo/estrela cadente, acima/abaixo EMA com o atual+ 3 ultimos volumes, pelo menos 2 acima de 3500.
int Sinal_1()
   {
      double valorEMA, aberturaCandle,fechamentoCandle, dif,dif_inf,dif_sup, limiteVolume,rangeEMAsuperior , rangeEMAinferior;
      
      limiteVolume = 3500.0;      
      aberturaCandle = rates[1].open;
      fechamentoCandle = rates[1].close;
      valorEMA = NormalizeDouble(ema[1],_Digits);
      
      if(Bullish())
      {
         rangeEMAsuperior = 30.0;
         rangeEMAinferior = -15.0;
         dif = aberturaCandle - valorEMA;
         dif_sup = fechamentoCandle - valorEMA;
         dif_inf = valorEMA - aberturaCandle; 
                
         //Verifica o range desejado entre a EMA
         if((dif <= rangeEMAsuperior) && (dif >= rangeEMAinferior))
         {
            //Verifica se o fechamento do candle esta acima da EMA 
            if(fechamentoCandle > valorEMA)
            {
               //Verifica se o candle está mais acima da EMA doque abaixo
               if(dif_sup > dif_inf)
               {
            
                  if(rates[1].tick_volume > limiteVolume && ( rates[2].tick_volume > limiteVolume || rates[3].tick_volume > limiteVolume || rates[4].tick_volume > limiteVolume ))
                  {
                     return 1;
                  }
                  else if((rates[1].tick_volume < limiteVolume && rates[2].tick_volume < limiteVolume) && (rates[3].tick_volume > limiteVolume && rates[4].tick_volume > limiteVolume))
                  {
                     return 1;
                  }
                  else if((rates[1].tick_volume < limiteVolume && rates[3].tick_volume < limiteVolume) && (rates[2].tick_volume > limiteVolume && rates[4].tick_volume > limiteVolume))
                  {
                     return 1;
                  }
                  else if((rates[1].tick_volume < limiteVolume && rates[4].tick_volume < limiteVolume) && (rates[2].tick_volume > limiteVolume && rates[3].tick_volume > limiteVolume))
                  {
                     return 1;
                  }
                  else if((rates[1].tick_volume < limiteVolume) && rates[2].tick_volume > limiteVolume && rates[3].tick_volume > limiteVolume && rates[4].tick_volume > limiteVolume)
                  {
                     return 1;
                  }              
                  else
                     return 0;
               }else
                  return 0;
            }else
               return 0;
          }else
            return 0;
      
      }else if(Bearish())
      {
         rangeEMAsuperior = -15.0;
         rangeEMAinferior = 30.0;
         dif = valorEMA - aberturaCandle;
         dif_sup = aberturaCandle - valorEMA;
         dif_inf = valorEMA - fechamentoCandle;
         
         if((dif <= rangeEMAinferior) && (dif >= rangeEMAsuperior))
         {
            //Verifica se o fechamento do candle esta abaixo da EMA
            if(fechamentoCandle < valorEMA)
            {
               //Verifica se o candle está mais abaixo da EMA doque acima
               if(dif_inf > dif_sup)
               {
            
                  if(rates[1].tick_volume >= limiteVolume && (rates[2].tick_volume > limiteVolume || rates[3].tick_volume > limiteVolume || rates[4].tick_volume > limiteVolume ))
                  {
                     return -1;
                  }
                  else if((rates[1].tick_volume < limiteVolume && rates[2].tick_volume < limiteVolume) && (rates[3].tick_volume > limiteVolume && rates[4].tick_volume > limiteVolume))
                  {
                     return -1;
                  }
                  else if((rates[1].tick_volume < limiteVolume && rates[3].tick_volume < limiteVolume) && (rates[2].tick_volume > limiteVolume && rates[4].tick_volume > limiteVolume))
                  {
                     return -1;
                  }
                  else if((rates[1].tick_volume < limiteVolume && rates[4].tick_volume < limiteVolume) && (rates[2].tick_volume > limiteVolume && rates[3].tick_volume > limiteVolume))
                  {
                     return -1;
                  }
                  else if((rates[1].tick_volume < limiteVolume) && rates[2].tick_volume > limiteVolume && rates[3].tick_volume > limiteVolume && rates[4].tick_volume > limiteVolume)
                  {
                     return -1;
                  }
                  else
                     return 0;
                }else 
                  return 0;
            }else
               return 0;
             
          }else
            return 0;
      }else
         return 0;
         
   return 0;
  }
  
//Estrategia 2: big bullish/berish bar com corpo >80 depois de 9 candles com open e close acima/abaixo da EMA, e com volume > 6000 no candle de entrada
int Sinal_2()
   {
      double valorEMA, aberturaCandle,fechamentoCandle, dif, distEMA, limiteVolume,rangeEMAsuperior , rangeEMAinferior;
      
      limiteVolume = 6000.0;      
      aberturaCandle = rates[1].open;
      fechamentoCandle = rates[1].close;
      valorEMA = NormalizeDouble(ema[1],_Digits);
            
      if(Bullish_2())
      {
         rangeEMAsuperior = 60.0;
         rangeEMAinferior = -15.0;
         dif = aberturaCandle - valorEMA;
         distEMA = fechamentoCandle - valorEMA;
         
         if((dif <= rangeEMAsuperior) && (dif >= rangeEMAinferior)) 
         {
            double count =0;
            if(distEMA < 200)
            {
               for(int i =2;i<=10;i++)
               {
                  if( rates[i].open > ema[i])
                  {
                    count= count+1; 
                  }
               }   
               if(count >= 9 && rates[1].tick_volume > limiteVolume)
               {
                  return 1;
               }
            }   
            
         }else
            return 0;
      
      }else if(Bearish_2())
      {
         rangeEMAsuperior = -15.0;
         rangeEMAinferior = 60.0;
         dif = valorEMA - aberturaCandle;
         distEMA = valorEMA - fechamentoCandle;
         
         if((dif <= rangeEMAinferior) && (dif >= rangeEMAsuperior))
         {
            double count =0;
            
            if(distEMA < 200)
            {
               for(int i =2;i<=10;i++)
               {
                  if(rates[i].open < ema[i])
                  {
                     count= count+1; 
                  }
               }
             }   
            
            if(count >= 9 && rates[1].tick_volume > limiteVolume)
            {
               return -1;
            }   
         }else
            return 0;
      }else
         return 0;
         
      return 0;
  }

//Estratégia 3: Big Bullish/Bearish bar com corpo >60 e >6000 de volume atravessando a EMA,  
int Sinal_3()
   {
      double valorEMA, aberturaCandle,fechamentoCandle, dif,dif_sup,dif_inf, limiteVolume,rangeEMAsuperior , rangeEMAinferior;
      
      limiteVolume = 6000.0;      
      aberturaCandle = rates[1].open;
      fechamentoCandle = rates[1].close;
      valorEMA = NormalizeDouble(ema[1],_Digits);
      
      if(Bullish_3())
      {
         rangeEMAsuperior = -5.0;
         rangeEMAinferior = -60.0;
         dif = aberturaCandle - valorEMA;
         dif_sup = fechamentoCandle - valorEMA;
         
         if((dif <= rangeEMAsuperior) && (dif >= rangeEMAinferior) && (rates[1].tick_volume > limiteVolume)) 
         {
            //Verifica se o range inferior é menor que o range superior
            if(dif_sup > (dif*-1))
            {
               return 1;
                                    
            }else
               return 0;                     
            
         }else
            return 0;
      
      }else if(Bearish_3())
      {
         rangeEMAsuperior = -60.0;
         rangeEMAinferior = -5.0;
         dif = valorEMA - aberturaCandle;
         dif_inf = fechamentoCandle - valorEMA;
         
         if((dif <= rangeEMAinferior) && (dif >= rangeEMAsuperior) && (rates[1].tick_volume > limiteVolume))
         {
            //Verifica se o range inferior é menor que o range superior
            if((dif_inf*-1) > (dif*-1))
            {
               return -1;
               
            }else
               return 0;     
         }else
            return 0;
      }else
         return 0;
         
      return 0;
  }
  
//Estratégia 4: Big Bullish/Bearish bar acima EMA com corpo >=60 e volume atual >7000 e 3 ultimos candles > 6000.  
int Sinal_4()
   {
      double valorEMA, aberturaCandle,fechamentoCandle, dif,dif_inf, limiteVolume,rangeEMAsuperior , rangeEMAinferior;
      
      limiteVolume = 6000.0;      
      aberturaCandle = rates[1].open;
      fechamentoCandle = rates[1].close;
      valorEMA = NormalizeDouble(ema[1],_Digits);
      
      if(Bullish_4())
      {
         rangeEMAsuperior = 20.0;
         rangeEMAinferior = 00.0;
         dif = aberturaCandle - valorEMA;
                  
         if((dif <= rangeEMAsuperior) && (dif >= rangeEMAinferior) && (rates[1].tick_volume > 7000.0) && (rates[2].tick_volume > 6000.0) && (rates[3].tick_volume > 6000.0) ) 
         {
            return 1;
         }else
            return 0;
      
      }else if(Bearish_4())
      {
         rangeEMAsuperior = 00.0;
         rangeEMAinferior = -20.0;
         dif = valorEMA - aberturaCandle;
         dif_inf = fechamentoCandle - valorEMA;
         
         if((dif <= rangeEMAinferior) && (dif >= rangeEMAsuperior) && (rates[1].tick_volume > 7000.0) && (rates[2].tick_volume > 6000.0) && (rates[3].tick_volume > 6000.0))
         {
            return -1;
         }else
            return 0;
      }else
         return 0;
         
      return 0;
  }

//Estratégia 5: Big Bullish/Bearish bar acima EMA com corpo >=80 e volume atual >9000 e 3 ultimos candles > 7000 tbm acima da EMA.  
int Sinal_5()
   {
      double valorEMA, aberturaCandle,fechamentoCandle, dif, limiteVolume,rangeEMAsuperior , rangeEMAinferior;
      
      limiteVolume = 6000.0;      
      aberturaCandle = rates[1].open;
      fechamentoCandle = rates[1].close;
      valorEMA = NormalizeDouble(ema[1],_Digits);
      
      if(Bullish_5())
      {
         rangeEMAinferior = 00.0;
         dif = aberturaCandle - valorEMA;
                  
         if((dif >= rangeEMAinferior) && (rates[1].tick_volume > 9000.0) && (rates[2].tick_volume > 7000.0) && (rates[3].tick_volume > 7000.0) && (rates[4].tick_volume > 7000.0) ) 
         {
            if(rates[2].open > ema[2] && rates[3].open > ema[3] && rates[4].open > ema[4] )
            {
               return 1;
            }
         }else
            return 0;
      
      }else if(Bearish_5())
      {
         rangeEMAsuperior = 00.0;
         dif = valorEMA - aberturaCandle;
                  
         if((dif >= rangeEMAsuperior) && (rates[1].tick_volume > 9000.0) && (rates[2].tick_volume > 7000.0) && (rates[3].tick_volume > 7000.0) && (rates[4].tick_volume > 7000.0))
         {
            if(rates[2].open < ema[2] && rates[3].open < ema[3] && rates[4].open < ema[4] )
            {
               return -1;
            }
         }else
            return 0;
      }else
         return 0;
         
      return 0;
  }

//Estratégia 6: Big Bullish/Bearish bar com corpo >=80 atravessando a EMA e >9000 de volume, os ultimos 3 candles >7000. ,  
int Sinal_6()
   {
      double valorEMA, aberturaCandle,fechamentoCandle, dif,dif_sup,dif_inf, limiteVolume,rangeEMAsuperior , rangeEMAinferior;
      
      limiteVolume = 9000.0;      
      aberturaCandle = rates[1].open;
      fechamentoCandle = rates[1].close;
      valorEMA = NormalizeDouble(ema[1],_Digits);
      
      if(Bullish_6())
      {
         rangeEMAsuperior = 30.0;
         rangeEMAinferior = -30.0;
         dif = aberturaCandle - valorEMA; // numero negativo
         dif_sup = fechamentoCandle - valorEMA; // numero positivo
         
         if((dif <= rangeEMAinferior) && (dif_sup >= rangeEMAsuperior) && (rates[1].tick_volume > limiteVolume) && (rates[2].tick_volume > 7000) && (rates[3].tick_volume > 7000) && (rates[4].tick_volume > 7000)) 
         {
            return 1;
         }else
            return 0;
      
      }else if(Bearish_6())
      {
         rangeEMAsuperior = -30.0;
         rangeEMAinferior = 30.0;
         dif = valorEMA - aberturaCandle; // numero negativo
         dif_inf = fechamentoCandle - valorEMA; // numero positivo
         
         if((dif <= rangeEMAsuperior) && (dif_inf >= rangeEMAinferior) && (rates[1].tick_volume > limiteVolume)&& (rates[2].tick_volume > 7000) && (rates[3].tick_volume > 7000) && (rates[4].tick_volume > 7000))
         {
            return -1;
                 
         }else
            return 0;
      }else
         return 0;
         
      return 0;
  }

void BuyMarket()
{
   PRC = ultimo_tick.ask;
   STL = NormalizeDouble(PRC-SL,_Digits);
   TKP = NormalizeDouble(PRC+TP,_Digits);
   
      if(trade.Buy(numContract,NULL,PRC,STL,TKP," Compra a mercado"))
      {
         Print("Buy Market sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
         barITraded = rates[0].time;
      }else
          Print("Buy Market com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
}

void SellMarket()
{
   PRC = ultimo_tick.bid;
   STL = NormalizeDouble(PRC+SL,_Digits);
   TKP = NormalizeDouble(PRC-TP,_Digits);
         
   if(trade.Sell(numContract,NULL,PRC,STL,TKP,"Venda a mercado"))
   {
      Print("Sell Stop sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
      barITraded = rates[0].time;
   }else
       Print("Sell Stop com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
}
  
void BuyStop()
{
   PRC = NormalizeDouble(rates[1].high+5.0,_Digits);
   STL = NormalizeDouble(PRC-SL,_Digits);
   TKP = NormalizeDouble(PRC+TP,_Digits);
             
   if(trade.BuyStop(numContract,PRC,NULL,STL,TKP,ORDER_TIME_SPECIFIED,(TimeCurrent()+3*60),"Compra ninja EA"))
   {
       Print("Buy Stop sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
       barITraded = rates[0].time;
   }else
       Print("Buy Stop com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
}

void SellStop()
{
   PRC = NormalizeDouble(rates[1].low-5.0,_Digits);
   STL = NormalizeDouble(PRC+SL,_Digits);
   TKP = NormalizeDouble(PRC-TP,_Digits);
         
   if(trade.SellStop(numContract,PRC,NULL,STL,TKP,ORDER_TIME_SPECIFIED,(TimeCurrent()+3*60),"Venda ninja EA"))
   {
       Print("Sell Stop sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
       barITraded = rates[0].time;
       
   }else
       Print("Sell Stop com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
}

void BuyLimit()
{
   PRC = NormalizeDouble(rates[1].close,_Digits);
   STL = NormalizeDouble(PRC-SL,_Digits);
   TKP = NormalizeDouble(PRC+TP,_Digits);
             
   if(trade.BuyLimit(numContract,PRC,NULL,STL,TKP,ORDER_TIME_SPECIFIED,(TimeCurrent()+2*60),"Compra ninja EA"))
   {
       Print("Buy Stop sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
       barITraded = rates[0].time;
             
   }else
       Print("Buy Stop com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
}

void SellLimit()
{
   PRC = NormalizeDouble(rates[1].close,_Digits);
   STL = NormalizeDouble(PRC+SL,_Digits);
   TKP = NormalizeDouble(PRC-TP,_Digits);
         
   if(trade.SellLimit(numContract,PRC,NULL,STL,TKP,ORDER_TIME_SPECIFIED,(TimeCurrent()+2*60),"Venda ninja EA"))
   {
       Print("Sell Stop sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
       barITraded = rates[0].time;
       
   }else
       Print("Sell Stop com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
}

void CancelOrder()
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      ulong orderTicket = OrderGetTicket(i);
      
      trade.OrderDelete(orderTicket);
   }
}

void Breakeven(double price)
{
   for(int i=PositionsTotal()-1; i>= 0; i--)
   {
      string symbol = PositionGetSymbol(i);
      ulong magic = PositionGetInteger(POSITION_MAGIC);
      
      if(symbol==_Symbol && magic == magicNum)
      {
         ulong positionTicket = PositionGetInteger(POSITION_TICKET);
         double precoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
         double takeProfitCorrente = PositionGetDouble(POSITION_TP);
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            if(price >= precoEntrada+gatilhoBE)
            {
               if(trade.PositionModify(positionTicket,precoEntrada,takeProfitCorrente))
               {
                  Print("Breakeven sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                  beAtivo = true;
               }else
                  Print("Breakeven com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
            }
         }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            if(price <= precoEntrada-gatilhoBE)
            {
               if(trade.PositionModify(positionTicket,precoEntrada,takeProfitCorrente))
               {
                  Print("Breakeven sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                  beAtivo = true;
               }else
                  Print("Breakeven com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
            }
         } 
      }
   }
   
}

void Parcial(double price, double lote_1, double target_1, double lote_2, double target_2)
{
   parcial_3_Ativo = false;
   
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      string symbol = PositionGetSymbol(i);
      ulong magic = PositionGetInteger(POSITION_MAGIC);
      
      if(symbol == _Symbol && magic == magicNum)
      {
         ulong positionTicket = PositionGetInteger(POSITION_TICKET);
         double precoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
         
         if(PositionGetInteger(POSITION_TYPE)== POSITION_TYPE_BUY)
         {
            if(price >= precoEntrada+target_1 && price < precoEntrada+target_2 && parcial_1_Ativo == false)
            {
               double preco_parcial_1 = NormalizeDouble(precoEntrada+target_1,_Digits); 
               if(trade.Sell(lote_1,NULL,preco_parcial_1))
               {
                  Print("Parcial 1 sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                  parcial_1_Ativo = true;
               }else
                     Print("Parcial 1 com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
               
               
             }else if(price >= precoEntrada+target_2 && parcial_2_Ativo == false)
               {
                  double preco_parcial_2 = NormalizeDouble(precoEntrada+target_2,_Digits); 
                  if(trade.Sell(lote_1,NULL,preco_parcial_2))
                  {
                     Print("Parcial 2 sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                     parcial_2_Ativo = true;
                     parcial_3_Ativo = true;                     
                  }else
                     Print("Parcial 2 com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
               }
         }else if(PositionGetInteger(POSITION_TYPE)== POSITION_TYPE_SELL)
            {
              if(price <= precoEntrada-target_1 && price > precoEntrada-target_2 && parcial_1_Ativo == false)
               {
                  double preco_parcial_1 = NormalizeDouble(precoEntrada-target_1,_Digits);
                  if(trade.Buy(lote_1,NULL,preco_parcial_1))
                  {
                     Print("Parcial1 sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                     parcial_1_Ativo = true;
                  }else
                     Print("Parcial 1 com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
               
               }else if(price <= precoEntrada-target_2 && parcial_2_Ativo == false)
               {
                  double preco_parcial_2 = NormalizeDouble(precoEntrada-target_2,_Digits); 
                  if(trade.Buy(lote_2,NULL,preco_parcial_2))
                  {
                     Print("Parcial 2 sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                     parcial_2_Ativo = true;
                     parcial_3_Ativo = true;
                  }else
                     Print("Parcial 2 com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
               } 
            }
      }
   
   }
}

void TrailingStop(double price)
{
   for(int i=PositionsTotal()-1; i>= 0; i--)
   {
      string symbol = PositionGetSymbol(i);
      ulong magic = PositionGetInteger(POSITION_MAGIC);
      
      if(symbol==_Symbol && magic == magicNum)
      {
         ulong positionTicket = PositionGetInteger(POSITION_TICKET);
         double precoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
         double takeProfitCorrente = PositionGetDouble(POSITION_TP);
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            if(price >= precoEntrada+gatilhoTS)
            {
               if(trade.PositionModify(positionTicket,precoEntrada+stepTS,takeProfitCorrente))
               {
                  Print("Trailing Stop sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
               }else
                  Print("Trailing Stop com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
            }
         }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            if(price <= precoEntrada-gatilhoTS)
            {
               if(trade.PositionModify(positionTicket,precoEntrada-stepTS,takeProfitCorrente))
               {
                  Print("Trailing Stop sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                  beAtivo = true;
               }else
                  Print("Trailing Stop com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
            }
         } 
      }
   }
}

bool Tem_Saldo(double saldo_ini, double capitalLiquido_ini)
{

   double saldo_atual, capitalLiquido_atual, balanco, capital_liquido;
   
   saldo_atual = AccountInfoDouble(ACCOUNT_BALANCE);
   capitalLiquido_atual = AccountInfoDouble(ACCOUNT_EQUITY);
   
   balanco = saldo_atual - saldo_ini;
   capital_liquido = capitalLiquido_atual - capitalLiquido_ini;
   
      if((balanco >= stop_diario) || (capital_liquido >= stop_diario))
      {
         return true;    
      }
      else
         return false;
   
   return false;
}