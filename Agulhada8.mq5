//+------------------------------------------------------------------+
//|                                            Agulhada do didi.mq5 |
//|                                                    Ismael Barros |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Ismael de Sousa Barros"
#property link      "https://www.mql5.com"
#property version   "8.0"

#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

input double numContract      = 3;        // Quantidade de Contratos
input double SL               = 100.0;    // StopLoss
input double TP               = 350.0;    // TakeProfit

input double gatilhoBE        = 100.0;     // Gatilho Breakeven
input double gatilhoTS        = 200.0;    // Gatilho trailing Stop
input double stepTS           = 100.0;     // Trailing Stop para primeira parcial
input double target1          = 50.0;     // Qtd de pontos Target 1
input double numContractTg1   = 1;        // Qtd de contratos Target 1
input double target2          = 200.0;    // Qtd de pontos Target 2
input double numContractTg2   = 1;        // Qtd de contratos Target 2

//Stop em Reais R$
input double stop_diario      = -1500.0;   // Stop Global Diário em R$

input string inicio           = "09:30";  // Horario de Inicio
input string termino          = "17:00";  // Horário de Termino
input string fechamento       = "17:30";  // Horario de Fechamento
input ulong  desvPts          = 30;       // Desvio
input ulong  magicNum         = 1290983;   // Magic number

double mediaCurta[], mediaMeio[], mediaLonga[];
int handleMediaCurta, handleMediaMeio, handleMediaLonga;

double PRC,STL,TKP;

double saldo_inicial, capitalLiquido_inicial;

bool beAtivo, cancelAtivo;
bool parcial_1_Ativo,parcial_2_Ativo,parcial_3_Ativo;
bool TSAtivo;
bool buyMarketAtivo, sellMarketAtivo; 

datetime barITraded, barCancelled, barIpendingOrdered;

MqlDateTime horario_inicio, horario_termino, horario_fechamento, horario_atual, tempo_expira;
MqlDateTime bar_atual, bar_order, bar_position, bar_parcial_3, bar_cancelled;
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
  
  ArraySetAsSeries(mediaCurta,true);
  ArraySetAsSeries(mediaMeio,true);
  ArraySetAsSeries(mediaLonga,true);
  ArraySetAsSeries(rates,true);
      
  handleMediaLonga = iMA(_Symbol,_Period,20,0,MODE_EMA,PRICE_CLOSE);
  handleMediaMeio = iMA(_Symbol,_Period, 9,0,MODE_EMA,PRICE_CLOSE);
  handleMediaCurta = iMA(_Symbol,_Period,3,0,MODE_EMA,PRICE_CLOSE);
     
   if(handleMediaCurta == INVALID_HANDLE || handleMediaLonga == INVALID_HANDLE || handleMediaMeio == INVALID_HANDLE)
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
      return;
     
   if(!SymbolInfoTick(_Symbol,ultimo_tick))
   {
      Print("Erro ao obter preço do ativo ",GetLastError());
      return;
   }
   //Captura os valores da media longa  
   CopyBuffer(handleMediaLonga,0,0,50,mediaLonga);
   //Captura os valores da media meio
   CopyBuffer(handleMediaMeio,0,0,50,mediaMeio);
   //Captura os valores da media curta
   CopyBuffer(handleMediaCurta,0,0,50,mediaCurta);
    
   //Captura os preços do grafico de 1 minuto
   CopyRates(_Symbol, _Period, 0, 31, rates);
              
   if(HorarioEntrada())
   {
      if(Tem_Saldo(saldo_inicial,capitalLiquido_inicial))
      {
         // Com posicao aberta e sem ordens pendentes abertas
         if(!SemPosicao() && SemOrdem())
         {
            MqlDateTime positionEntrance, currentBar, tempoAtual;
                                              
            TimeToStruct(barITraded, positionEntrance);
            TimeToStruct(rates[0].time, currentBar);
            TimeToStruct(TimeCurrent(), tempoAtual);
            
            double volumeAtual = PositionGetDouble(POSITION_VOLUME);
            
            // Se houver posicao com um numero maior de contratos doque planejado
            if(volumeAtual > numContract && !beAtivo && !parcial_1_Ativo)
            {
               CancelPosition();
            
            }
            
               if(!beAtivo)
               {
                  Breakeven(ultimo_tick.last);
                  
               }else if(beAtivo)
               {
                  if(parcial_1_Ativo == false && parcial_2_Ativo == false)
                  {
                     Parcial(ultimo_tick.last,numContractTg1, target1, numContractTg2, target2);
                  
                  }else if(parcial_1_Ativo == true && parcial_2_Ativo == false)
                  {
                     Parcial(ultimo_tick.last,numContractTg1, target1, numContractTg2, target2);
                  
                  }else if(parcial_2_Ativo == true)
                  {
                     if(TSAtivo == false)
                     {
                        TrailingStop(ultimo_tick.last);
                     }
                  }
               }
               if(currentBar.hour > positionEntrance.hour || currentBar.min > positionEntrance.min)
               {
                  long tipo = PositionGetInteger(POSITION_TYPE);
                  double precoBE = PositionGetDouble(POSITION_PRICE_OPEN);
                                                      
                  if(tipo == POSITION_TYPE_SELL)
                  {
                     if(Agulhada() && BullishBarAtual())
                     {
                        ENUM_POSITION_PROPERTY_DOUBLE stoplossOpenPos = (ENUM_POSITION_PROPERTY_DOUBLE)NormalizeDouble(PositionGetDouble(POSITION_SL),_Digits); 
                        double orderEntradaBuy = simbolo.NormalizePrice(NormalizeDouble(rates[1].high+5,_Digits));
                        
                        if(!Filtro_1() && !Filtro_2() && !Filtro_3() && Filtro_4())
                        {   //Vira a mao quando ainda não atingiu a primeira parcial                     
                           if((stoplossOpenPos > orderEntradaBuy+5) && (ultimo_tick.last <= orderEntradaBuy)  && !parcial_1_Ativo)
                           {
                              ViraMaoComprado();
                           
                           }
                        }
                     }
                  }else if(tipo == POSITION_TYPE_BUY)
                  {
                     if(Agulhada() && BearishBarAtual())
                     {
                        ENUM_POSITION_PROPERTY_DOUBLE stoplossOpenPos = (ENUM_POSITION_PROPERTY_DOUBLE)NormalizeDouble(PositionGetDouble(POSITION_SL),_Digits);
                        double orderEntradaSell = NormalizeDouble(rates[1].low-5,_Digits );
                        
                        if(!Filtro_1() && !Filtro_2() && !Filtro_3() && Filtro_4()) 
                        {   
                            //Vira a mao quando ainda não atingiu a primeira parcial
                           if((stoplossOpenPos < orderEntradaSell-5) && (ultimo_tick.last >= orderEntradaSell) && !parcial_1_Ativo)
                           {
                              ViraMaoVendido();
                           
                           }
                        }
                     }
                  }
                     
               }
            
         }
         //Ordem pendente com posicao aberta
         if(!SemOrdem() && !SemPosicao())
          {
            TimeToStruct(TimeCurrent(),bar_atual);
            TimeToStruct(barIpendingOrdered,bar_order);
                            
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP)
            {
               if(bar_atual.hour > bar_order.hour || bar_atual.min > bar_order.min)
               {
                  CancelOrder();
               }
               
             }else if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP)
               {
                  if(bar_atual.hour > bar_order.hour || bar_atual.min > bar_order.min)
                  {
                     CancelOrder();
                  }
                     
               }
            }
          //Ordem pendente sem posicao aberta
          if(!SemOrdem() && SemPosicao())
          {
            TimeToStruct(TimeCurrent(),bar_atual);
            TimeToStruct(barITraded,bar_order);
                            
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP)
            {
               if(bar_atual.hour > bar_order.hour || bar_atual.min > bar_order.min)
               {
                  CancelOrder();
               }
               
             }else if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP)
               {
                  if(bar_atual.hour > bar_order.hour || bar_atual.min > bar_order.min)
                  {
                     CancelOrder();
                  }
                     
               }
            }
            
            // Verifica se não há nenhuma posição ou ordem em aberto
            if(SemPosicao() && SemOrdem())
            {
               parcial_1_Ativo = false;
               parcial_2_Ativo = false;
               beAtivo = false;
               TSAtivo = false;
               buyMarketAtivo = false;
               sellMarketAtivo = false;
                                             
               TimeToStruct(TimeCurrent(),bar_atual);
               TimeToStruct(barITraded,bar_order);
               TimeToStruct(rates[0].time,bar_parcial_3);
               TimeToStruct(barCancelled, bar_cancelled);
               
               if(!Filtro_1() && !Filtro_2() && !Filtro_3() && Filtro_4())
               {
                  if(Agulhada())
                  {
                     if(BullishBarAtual())
                     {
                        BuyStop();
                     
                     }else if(BearishBarAtual())
                     {
                        SellStop();
                     }                          
                  
                  }
               }
               
            }  
      }
   }
                
   if(HorarioFechamento())
   {
      if(!SemPosicao() || !SemOrdem())
      {
         FecharPosicao();
         FecharOrdem();
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

void FecharPosicao()
{
   if(!PositionSelect(_Symbol))
   {
      return;
   }
   long tipo = PositionGetInteger(POSITION_TYPE);
      
      if(!parcial_1_Ativo)
      {
      
         if(tipo == POSITION_TYPE_BUY)
         {
            trade.Sell(numContract,NULL,0,0,0,"Fechamento ninja EA");
         }
         else
            trade.Buy(numContract,NULL,0,0,0,"Fechamento ninja EA");
      }
      if(parcial_1_Ativo && !parcial_2_Ativo)
      {
      
         if(tipo == POSITION_TYPE_BUY)
         {
            trade.Sell(numContract-numContractTg1,NULL,0,0,0,"Fechamento ninja EA");
         }
         else
            trade.Buy(numContract-numContractTg1,NULL,0,0,0,"Fechamento ninja EA");
      }
      if(parcial_2_Ativo)
      {
      
         if(tipo == POSITION_TYPE_BUY)
         {
            trade.Sell(numContract-numContractTg1-numContractTg2,NULL,0,0,0,"Fechamento ninja EA");
         }
         else
            trade.Buy(numContract-numContractTg1-numContractTg2,NULL,0,0,0,"Fechamento ninja EA");
      }
}

void FecharOrdem()
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      ulong orderTicket = OrderGetTicket(i);
      
      trade.OrderDelete(orderTicket);
   }
}

bool BullishBarAtual() 
   {
            
      //Verifica se é bullish bar         
      if(rates[1].close > rates[1].open)
         return true;
        
   return false;  
   }
   
//Estrategia 1 - Bullish bar  
bool BearishBarAtual() 
   {
            
      //Verifica se é bearish bar
      if(rates[1].close < rates[1].open)
         return true;
              
   return false;  
   }
   
bool BullishBarAnterior() 
   {
      double rabicho_cima = rates[2].high - rates[2].close;
      double rabicho_baixo = rates[2].open - rates[2].low;
      double corpo = rates[2].close - rates[2].open;
      
      //Verifica se é bullish bar         
      if((rates[2].close > rates[2].open))
      {
         if(corpo > rabicho_cima)
            return true;
      }
        
   return false;  

   }
   
//Estrategia 1 - Bullish bar  
bool BearishBarAnterior() 
   {
      double rabicho_cima = rates[2].high - rates[2].open;
      double rabicho_baixo = rates[2].close - rates[2].low;
      double corpo = rates[2].open - rates[2].close;
      
      //Verifica se é bearish bar
      if(rates[2].close < rates[2].open)
      {
         if(corpo > rabicho_baixo)
            return true;
      }
              
   return false;  

   }

bool Agulhada()
{
   double candleFechadoHigh = rates[1].high;
   double candleFechadoLow = rates[1].low;
   
   if((mediaCurta[1] < candleFechadoHigh && mediaCurta[1] > candleFechadoLow) &&
       (mediaMeio[1] < candleFechadoHigh && mediaMeio[1] > candleFechadoLow) &&
       (mediaLonga[1] < candleFechadoHigh && mediaLonga[1] > candleFechadoLow) )
     {
         return true;
     }
   
   return false;
}

void ViraMaoComprado()
{
         long tipo = PositionGetInteger(POSITION_TYPE);
         double volumeAtual = PositionGetDouble(POSITION_VOLUME);
         double preco_entrada = simbolo.NormalizePrice(NormalizeDouble(rates[1].high+5.0,_Digits));
         double stoploss = simbolo.NormalizePrice(NormalizeDouble(rates[1].low-5.0,_Digits));
         double takeprofit = simbolo.NormalizePrice(NormalizeDouble(preco_entrada+TP,_Digits));
   
         double qtd = numContract;
   
          if(tipo == POSITION_TYPE_SELL)
          {
               if(volumeAtual == numContract && !parcial_1_Ativo)
               {         
                           
                  if(trade.BuyStop(qtd+numContract,preco_entrada,NULL,stoploss,takeprofit,0,0,"Virando a mao vendendo"))
                  {
                     Print("Buy Stop na virada de mao sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                     barIpendingOrdered = rates[0].time;
                     Print("numero de contratos antes da primeira parcial : ", volumeAtual);
                     volumeAtual = numContract;
                  }
                  else
                     Print("Buy Stop na virada de mao com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
               
               }else if(volumeAtual == (numContract - numContractTg1) && parcial_1_Ativo && !parcial_2_Ativo)
               {
                  if(trade.BuyStop(qtd+(numContract - numContractTg1),preco_entrada,NULL,stoploss,takeprofit,0,0,"Virando a mao vendendo"))
                  {
                     Print("Buy Stop na virada de mao sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                     barIpendingOrdered = rates[0].time;
                     Print("numero de contratos antes da segunda parcial : ", volumeAtual);
                     volumeAtual = numContract;
                  }
                  else
                     Print("Buy Stop na virada de mao com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());   
               
               }else if(volumeAtual == (numContract - (numContractTg1 + numContractTg2)) && parcial_2_Ativo)
               {
                 if(trade.BuyStop(qtd+(numContract - (numContractTg1 + numContractTg2)),preco_entrada,NULL,stoploss,takeprofit,0,0,"Virando a mao vendendo"))
                  {
                     Print("Buy Stop na virada de mao sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                     barIpendingOrdered = rates[0].time;
                     Print("numero de contratos antes do take profit : ", volumeAtual);
                     volumeAtual = numContract;
                  }
                  else
                     Print("Buy Stop na virada de mao com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
               }
         }
}

void ViraMaoVendido()
{
         long tipo = PositionGetInteger(POSITION_TYPE);
         double volumeAtual = PositionGetDouble(POSITION_VOLUME);
         double preco_entrada = simbolo.NormalizePrice(NormalizeDouble(rates[1].low-5.0,_Digits));
         double stoploss = simbolo.NormalizePrice(NormalizeDouble(rates[1].high+5.0,_Digits));
         double takeprofit = simbolo.NormalizePrice(NormalizeDouble(preco_entrada-TP,_Digits));
   
         double qtd = numContract;
   
         if(tipo == POSITION_TYPE_BUY)
         {
               if(volumeAtual == numContract && !parcial_1_Ativo)
               {
                  if(trade.SellStop(qtd+numContract,preco_entrada,NULL,stoploss,takeprofit,0,0,"Virando a mao vendendo"))
                  {
                     Print("Sell Stop na virada de mao sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                     barIpendingOrdered = rates[0].time;
                     Print("numero de contratos antes da primeira parcial : ", volumeAtual);
                     volumeAtual = numContract;
                  }   
                  else
                     Print("Sell Stop na virada de mao com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
               
               }else if(volumeAtual == (numContract - numContractTg1) && parcial_1_Ativo && !parcial_2_Ativo)
               {
                  if(trade.SellStop(qtd+(numContract - numContractTg1),preco_entrada,NULL,stoploss,takeprofit,0,0,"Virando a mao vendendo"))
                  {
                     Print("Sell Stop na virada de mao sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                     barIpendingOrdered = rates[0].time;
                     Print("numero de contratos antes da segunda parcial : ", volumeAtual);
                     volumeAtual = numContract;
                  }
                  else
                     Print("Sell Stop na virada de mao com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());   
               
               }else if(volumeAtual == (numContract - (numContractTg1 + numContractTg2)) && parcial_2_Ativo)
               {
                 if(trade.SellStop(qtd+(numContract - (numContractTg1 + numContractTg2)),preco_entrada,NULL,stoploss,takeprofit,0,0,"Virando a mao vendendo"))
                  {
                     Print("Sell Stop na virada de mao sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                     barIpendingOrdered = rates[0].time;
                     Print("numero de contratos antes do take profit : ", volumeAtual);
                     volumeAtual = numContract;
                  }
                  else
                     Print("Sell Stop na virada de mao com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription()); 
               
               }
         }
}

bool Filtro_1()
{
   double limiteVolume = 3500;
   ulong v1 = rates[1].tick_volume;
   ulong v2 = rates[2].tick_volume;
   ulong v3 = rates[3].tick_volume;
   ulong v4 = rates[4].tick_volume;
   double media = (double)(v1+v2+v3+v4)/4;
   
   if((v1 < limiteVolume && v2 < limiteVolume && v3 < limiteVolume && v4 < limiteVolume) || media < limiteVolume)
   {
      return true;
   }
   return false;
}

bool Filtro_2()
{
   double candleFechadoHigh1 = rates[1].high;
   double candleFechadoLow1 = rates[1].low;
   double range_cima = candleFechadoHigh1 - mediaLonga[1];
   double range_baixo = mediaLonga[1] - candleFechadoLow1;
      
   if(range_cima > 150 || range_baixo > 150 )
   {
      return true;
   }
   
   return false;
}

bool Filtro_3()
{
   double candleFechadoHigh1 = rates[1].high;
   double candleFechadoLow1 = rates[1].low;
   double candleFechadoHigh2 = rates[2].high;
   double candleFechadoLow2 = rates[2].low;
   double candleFechadoHigh3 = rates[3].high;
   double candleFechadoLow3 = rates[3].low;
   double candleFechadoHigh4 = rates[4].high;
   double candleFechadoLow4 = rates[4].low;
   
   if((mediaCurta[1] <= candleFechadoHigh1 && mediaCurta[1] >= candleFechadoLow1) &&
       (mediaMeio[1] <= candleFechadoHigh1 && mediaMeio[1] >= candleFechadoLow1) &&
       (mediaLonga[1] <= candleFechadoHigh1 && mediaLonga[1] >= candleFechadoLow1) )
     {
         if((mediaCurta[2] <= candleFechadoHigh2 && mediaCurta[2] >= candleFechadoLow2) &&
            (mediaMeio[2] <= candleFechadoHigh2 && mediaMeio[2] >= candleFechadoLow2) &&
            (mediaLonga[2] <= candleFechadoHigh2 && mediaLonga[2] >= candleFechadoLow2) )
         {
            if((mediaCurta[3] <= candleFechadoHigh3 && mediaCurta[3] >= candleFechadoLow3) &&
               (mediaMeio[3] <= candleFechadoHigh3 && mediaMeio[3] >= candleFechadoLow3) &&
               (mediaLonga[3] <= candleFechadoHigh3 && mediaLonga[3] >= candleFechadoLow3) )
            {
               if((mediaCurta[4] <= candleFechadoHigh4 && mediaCurta[4] >= candleFechadoLow4) &&
                  (mediaMeio[4] <= candleFechadoHigh4 && mediaMeio[4] >= candleFechadoLow4) &&
                  (mediaLonga[4] <= candleFechadoHigh4 && mediaLonga[4] >= candleFechadoLow4) )
               {
                  return true;           
         
               }
         
            } 
         
         }   
     }
   
   return false;
}

bool Filtro_4()
{
   double rabicho_cima = rates[1].high - rates[1].close;
   double rabicho_baixo = rates[1].close - rates[1].low;
   double corpoBullish_atual = rates[1].close - rates[1].open;
   double corpoBearish_atual = rates[1].open - rates[1].close;
         
   if(BullishBarAtual())
   {
      if(corpoBullish_atual <= 30 && rabicho_cima >= corpoBullish_atual)
      {
         if(BullishBarAnterior())
         {
            return true;
         }else
            return false;
      }else
         return true;
         
   }else if(BearishBarAtual())
   {
      if(corpoBearish_atual <= 30 && rabicho_baixo >= corpoBearish_atual)
      {
         if(BearishBarAnterior())
         {
            return true;
         
         }else
            return false;
      }else
         return true;
   }
      
   return false;
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
         buyMarketAtivo = true;
         cancelAtivo = false;
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
      Print("Sell Market sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
      barITraded = rates[0].time;
      sellMarketAtivo = true;
      cancelAtivo = false;
   }else
       Print("Sell Market com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
}
  
void BuyStop()
{
   PRC = simbolo.NormalizePrice(NormalizeDouble(rates[1].high+5.0,_Digits));
   STL = simbolo.NormalizePrice(NormalizeDouble(rates[1].low-5.0,_Digits));
   TKP = simbolo.NormalizePrice(NormalizeDouble(PRC+TP,_Digits));
                
   if(trade.BuyStop(numContract,PRC,NULL,STL,TKP,0,0,"Compra ninja EA"))
   {
       Print("Buy Stop sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
       barITraded = rates[0].time;
   }else
       Print("Buy Stop com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
}

void SellStop()
{
   PRC = simbolo.NormalizePrice(NormalizeDouble(rates[1].low-5.0,_Digits));
   STL = simbolo.NormalizePrice(NormalizeDouble(rates[1].high+5.0,_Digits));
   TKP = simbolo.NormalizePrice(NormalizeDouble(PRC-TP,_Digits));
         
   if(trade.SellStop(numContract,PRC,NULL,STL,TKP,0,0,"Venda ninja EA"))
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
       Print("Buy Limit sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
       barITraded = rates[0].time;
             
   }else
       Print("Buy Limit com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
}

void SellLimit()
{
   PRC = NormalizeDouble(rates[1].close,_Digits);
   STL = NormalizeDouble(PRC+SL,_Digits);
   TKP = NormalizeDouble(PRC-TP,_Digits);
         
   if(trade.SellLimit(numContract,PRC,NULL,STL,TKP,ORDER_TIME_SPECIFIED,(TimeCurrent()+2*60),"Venda ninja EA"))
   {
       Print("Sell Limit sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
       barITraded = rates[0].time;
       
   }else
       Print("Sell Limit com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
}

void CancelOrder()
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      ulong orderTicket = OrderGetTicket(i);
      
      trade.OrderDelete(orderTicket);
   }
}

void CancelPosition()
{
   if(!PositionSelect(_Symbol))
   {
      return;
   }
   long tipo = PositionGetInteger(POSITION_TYPE);
   double volumeAtual = PositionGetDouble(POSITION_VOLUME);
      
      if(!parcial_1_Ativo)
      {
      
         if(tipo == POSITION_TYPE_BUY)
         {
            trade.Sell(volumeAtual,NULL,0,0,0,"Fechamento ninja EA");
            Print("Posição cancelada devido ao erro de qtd de contrato ser maior que o configurado");
         }
         else
            trade.Buy(volumeAtual,NULL,0,0,0,"Fechamento ninja EA");
            Print("Posição cancelada devido ao erro de qtd de contrato ser maior que o configurado");
      }
      if(parcial_1_Ativo && !parcial_2_Ativo)
      {
      
         if(tipo == POSITION_TYPE_BUY)
         {
            trade.Sell(volumeAtual,NULL,0,0,0,"Fechamento ninja EA");
            Print("Posição cancelada devido ao erro de qtd de contrato ser maior que o configurado");
         }
         else
            trade.Buy(volumeAtual,NULL,0,0,0,"Fechamento ninja EA");
            Print("Posição cancelada devido ao erro de qtd de contrato ser maior que o configurado");
      }
      if(parcial_2_Ativo)
      {
      
         if(tipo == POSITION_TYPE_BUY)
         {
            trade.Sell(volumeAtual,NULL,0,0,0,"Fechamento ninja EA");
            Print("Posição cancelada devido ao erro de qtd de contrato ser maior que o configurado");
         }
         else
            trade.Buy(volumeAtual,NULL,0,0,0,"Fechamento ninja EA");
            Print("Posição cancelada devido ao erro de qtd de contrato ser maior que o configurado");
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
                     Print("Parcial 1 sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
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
                  TSAtivo = true;
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
                  TSAtivo = true;
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


