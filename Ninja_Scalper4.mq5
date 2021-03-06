//+------------------------------------------------------------------+
//|                                            Ninja_Scalper.mq5 |
//|                                                    Ismael Barros |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Ismael de Sousa Barros"
#property link      "https://www.mql5.com"
#property version   "2.0"

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

input string inicio           = "09:30";  // Horario de Inicio
input string termino          = "17:00";  // Horário de Termino
input string fechamento       = "17:30";  // Horario de Fechamento
input ulong  desvPts          = 30;       // Desvio
input ulong  magicNum         = 1298983;   // Magic number

double mediaCurta[], mediaLonga[];
int handleMediaCurta, handleMediaLonga;

double PRC,STL,TKP;

double saldo_inicial, capitalLiquido_inicial;

bool beAtivo, cancelAtivo;
bool parcial_1_Ativo,parcial_2_Ativo,parcial_3_Ativo;
bool TSAtivo;
bool buyMarketAtivo, sellMarketAtivo; 

datetime barITraded, barCancelled;

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
  ArraySetAsSeries(mediaLonga,true);
  ArraySetAsSeries(rates,true);
      
  handleMediaLonga = iMA(_Symbol,_Period,9,0,MODE_EMA,PRICE_CLOSE);
  handleMediaCurta = iMA(_Symbol,_Period,3,0,MODE_EMA,PRICE_CLOSE);
     
   if(handleMediaCurta == INVALID_HANDLE || handleMediaLonga == INVALID_HANDLE)
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
   //Captura os valores da media curta
   CopyBuffer(handleMediaCurta,0,0,50,mediaCurta);
    
   //Captura os preços do grafico de 1 minuto
   CopyRates(_Symbol, _Period, 0, 31, rates);
              
   if(HorarioEntrada())
   {
      if(Tem_Saldo(saldo_inicial,capitalLiquido_inicial))
      {
         if(!SemPosicao())
         {
            MqlDateTime positionEntrance, currentBar, tempoAtual;
                                              
            TimeToStruct(barITraded, positionEntrance);
            TimeToStruct(rates[0].time, currentBar);
            TimeToStruct(TimeCurrent(), tempoAtual);
            
            long tipo = PositionGetInteger(POSITION_TYPE);
                        
            if(positionEntrance.min != currentBar.min)
            {
               if(ConfirmaCruzamento() == 0 && beAtivo == false)
               {
                  // evita o cancelamento no mesmo instante da entrada
                  if(positionEntrance.min + 1 == tempoAtual.min)                  
                     CancelPosition();
               }
                  //cancela a posicao se houver um cruzamento do lado oposto
               if(tipo == POSITION_TYPE_BUY && Cruzamento() == -1)
               {
                  // evita o cancelamento no mesmo instante da entrada
                  if(positionEntrance.min + 1 == tempoAtual.min)                  
                     CancelPosition();
               
               }else if(tipo == POSITION_TYPE_SELL && Cruzamento() == 1)
               {
                  // evita o cancelamento no mesmo instante da entrada
                  if(positionEntrance.min + 1 == tempoAtual.min)                  
                     CancelPosition();
               }
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
               
               if(cancelAtivo == true)
               {
                  if(ConfirmaCruzamento() == 1)
                  {
                     BuyMarket();
                  
                  }else if(ConfirmaCruzamento() == -1)
                  {
                     SellMarket();
                  }
               }
               if(Cruzamento() == 1 && VerificaRange() == true)
               {
                     if((bar_atual.min > bar_cancelled.min+1) && bar_cancelled.min != 59)
                     {
                        BuyMarket();
                        
                     }else if ((bar_cancelled.min == 59) && (bar_atual.min > 0))
                     {
                        BuyMarket();
                     
                     }else if(bar_atual.min > bar_order.min+1)
                     {
                        BuyMarket();
                     }                  
               
               }else if(Cruzamento() == -1 && VerificaRange() == true)
               {
                     if((bar_atual.min > bar_cancelled.min+1) && bar_cancelled.min != 59)
                     {
                        SellMarket();
                        
                     }else if ((bar_cancelled.min == 59) && (bar_atual.min > 0))
                     {
                        SellMarket();
                     
                     }else if(bar_atual.min > bar_order.min+1)
                     {
                        SellMarket();
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
  
int Cruzamento()
{
                                    
      //compra
      if(mediaCurta[1] <= mediaLonga[1] && mediaCurta[0] > mediaLonga[0])
      {
         return 1;
               
      }else if(mediaCurta[1] >= mediaLonga[1] && mediaCurta[0] < mediaLonga[0])
      {
         return -1;
      }
                                            
   return 0;
} 

int ConfirmaCruzamento()
{
         
   for(int i=PositionsTotal()-1; i>= 0; i--)
   {
      string symbol = PositionGetSymbol(i);
      ulong magic = PositionGetInteger(POSITION_MAGIC);
            
      if(symbol==_Symbol && magic == magicNum)
      {
                  
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            if(mediaCurta[2] <= mediaLonga[2] && mediaCurta[1] > mediaLonga[1])
               return 1;
                                         
         }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            if(mediaCurta[2] >= mediaLonga[2] && mediaCurta[1] < mediaLonga[1])
               return -1;
         }
      }
   }
   return 0;

}

bool VerificaRange()
{
   double tradingrange;
   int lowestCandle, highestCandle;
   double high[], low[];
   
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
      
   CopyHigh(_Symbol, _Period, 0, 31, high);
   CopyLow(_Symbol, _Period, 0, 31, low);
   
   highestCandle = ArrayMaximum(high,0,31);
   lowestCandle = ArrayMinimum(low,0,31);
   
   tradingrange = rates[highestCandle].high - rates[lowestCandle].low;
   Comment("The current range is:  ", tradingrange);
      
   if(tradingrange > 300)
   {
      return true;
      
   }else if(tradingrange < 300 && rates[1].tick_volume > 7000)
   {
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
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong positionTicket = PositionGetTicket(i);
      
      if(trade.PositionClose(positionTicket))
      {
         Print("Posicao cancelada sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
         barCancelled = rates[0].time;
         cancelAtivo = true;
      }        
      else
         Print("Posicao cancelada com falha: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
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
