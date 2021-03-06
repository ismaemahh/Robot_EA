//+------------------------------------------------------------------+
//|                                            Cruzamento_mediaEA.mq5 |
//|                                                    Ismael Barros |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Ismael Barros"
#property link      "https://www.mql5.com"
#property version   "4.0"

#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

input int                  periodoLongo   = 8;          // periodo media longa
input int                  periodoCurto   = 3;          // periodo media curta
input ENUM_MA_METHOD       maCurtoMetodo  = MODE_EMA;    // Metodo Media Movel de periodo Curto
input ENUM_MA_METHOD       maLongoMetodo  = MODE_EMA;    // Metodo Media Movel de periodo longo
input ulong                desvPts        = 30;          // Desvio
input ulong                magicNum       = 123456;      // Magic number

input double               Volume         = 2;           // Volume
input double               SL             = 100.0;       // Stop Loss
input double               TP             = 100.0;       // Take Profit
input double               gatilhoBE      = 50.0;        // BreakEven
input string               inicio         = "09:05";     // Horaro de Inicio (Entrada)
input string               termino        = "16:45";     // Horaro de Termino (Entrada)
input string               fechamento     = "17:00";     // Horaro de Inicio (Posicoes)
input double               distancia      = 110.0;       // Distancia do Cruzamento das Medias  

double mediaCurta[], mediaLonga[];
double PRC,STL,TKP;

bool beAtivo;

int handlemedialonga, handlemediacurta;

CTrade trade;
CSymbolInfo simbolo;

MqlDateTime horario_inicio, horario_termino, horario_fechamento, horario_atual;
MqlRates rates[];
MqlTick ultimo_tick;

int OnInit(){
  
   if(!simbolo.Name(_Symbol)){
      Print("Ativo invalido");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(mediaCurta,true);
   ArraySetAsSeries(mediaLonga,true);
   ArraySetAsSeries(rates,true);
      
   handlemediacurta = iMA(_Symbol,_Period,periodoCurto,0,maCurtoMetodo,PRICE_CLOSE);
   handlemedialonga = iMA(_Symbol,_Period,periodoLongo,0,maLongoMetodo,PRICE_CLOSE);
      
   if(handlemediacurta == INVALID_HANDLE || handlemedialonga == INVALID_HANDLE){
      Print("Erro na criação dos manipuladores ");
      return INIT_FAILED;
   }
   if(handlemedialonga <= handlemediacurta){
      Print("Parametro de medias incorretos");
      return INIT_FAILED;
   }  
   
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   trade.SetDeviationInPoints(desvPts);
   trade.SetExpertMagicNumber(magicNum);
   
   TimeToStruct(StringToTime(inicio), horario_inicio);
   TimeToStruct(StringToTime(termino), horario_termino);
   TimeToStruct(StringToTime(fechamento), horario_fechamento);
   
   if(horario_inicio.hour > horario_termino.hour || (horario_inicio.hour == horario_termino.hour && horario_inicio.min >= horario_termino.min)){
      printf("Parametros de horario invalido");
      
      return INIT_FAILED;      
   }
   if(horario_termino.hour > horario_fechamento.hour || (horario_termino.hour == horario_fechamento.hour && horario_termino.min >= horario_fechamento.min)){
      printf("Parametros de horario invalido");
      
      return INIT_FAILED;      
   }     

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   printf("Deinit reason : %d",reason);
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
     
   if(!simbolo.RefreshRates()){
      return;
   }
   
   if(!SymbolInfoTick(_Symbol,ultimo_tick)){
      Print("Erro ao obter preço do ativo ",GetLastError());
      return;
   }
   
   if(CopyRates(_Symbol,_Period,0,20,rates) < 0){
      Alert("Erro ao obter informaçãoes de MqlRates ",GetLastError());
      return;
   }
   
   if(HorarioEntrada()){
      if(!SemPosicao()){
            //Comment("ultimo preco", ultimo_tick.last,"preco de entrada: ", PositionGetDouble(POSITION_PRICE_OPEN),"preco target: ",PositionGetDouble(POSITION_TP));
            Breakeven(ultimo_tick.last);            
      }
      if(SemPosicao()){
         int resultado_cruzamento = Cruzamento();
         beAtivo = false;
         
         if(resultado_cruzamento == 1){
            Compra();
         }
         if(resultado_cruzamento == -1){
            Venda();
         }
      }         
   }
   if(HorarioFechamento()){
      if(!SemPosicao()){
         Fechar();
      }
   }
}
   
   bool HorarioEntrada(){
   
      TimeToStruct(TimeCurrent(), horario_atual);
      
      if((horario_atual.hour >= horario_inicio.hour) && (horario_atual.hour <= horario_termino.hour)){
            
            if(horario_atual.hour == horario_inicio.hour){
               if(horario_atual.min >= horario_inicio.min){
                  return true;            
            }
            else
               return false;
         }       
       if(horario_atual.hour == horario_termino.hour){
            if(horario_atual.min <= horario_termino.min){
               return true;            
            }
            else
               return false;
         }         
         return true;         
      }   
      return false;
   }
   
   bool HorarioFechamento(){
   
      TimeToStruct(TimeCurrent(), horario_atual);
      
      if(horario_atual.hour >= horario_fechamento.hour){
         if(horario_atual.hour == horario_fechamento.hour){
            if(horario_atual.min >= horario_fechamento.min){
               
               return true;            
            }
            else
               return false;         
         }         
         return true;      
      }      
      return false;      
   }
      
   void Compra(){
      
      PRC = NormalizeDouble(ultimo_tick.ask,_Digits);
      STL = NormalizeDouble(PRC-SL,_Digits);
      TKP = NormalizeDouble(PRC+TP,_Digits);
            
         
      double precoDist = NormalizeDouble(DistanciaCruzamento(),_Digits);
      
      if((PRC - precoDist) < distancia){
         if((PRC) > rates[1].high){
            trade.Buy(Volume, NULL,PRC,STL,TKP,"Compra cruzamento media EA");
         }
      }     
   }
   void Venda(){
      
      PRC = NormalizeDouble(ultimo_tick.bid,_Digits);
      STL = NormalizeDouble(PRC+SL,_Digits);
      TKP = NormalizeDouble(PRC-TP,_Digits);
   
            
      double precoDist = NormalizeDouble(DistanciaCruzamento(),_Digits);
      
      if((precoDist - PRC) < distancia){
         if((PRC) < rates[1].low){
            trade.Sell(Volume, NULL,PRC,STL,TKP,"Venda cruzamento media EA");
         }
      }
   }
   
   void Fechar(){
   
      if(!PositionSelect(_Symbol)){
         return;
      }
      
      long tipo = PositionGetInteger(POSITION_TYPE);
      
      if(tipo == POSITION_TYPE_BUY){
         trade.Sell(Volume,NULL,0,0,0,"Fechamento cruzamento media EA");
      }
      else
         trade.Buy(Volume,NULL,0,0,0,"Fechamento cruzamento media EA");
   
   }
   bool SemPosicao(){
      return !PositionSelect(_Symbol);
   }
   int Cruzamento(){
      
      CopyBuffer(handlemediacurta,0,0,2,mediaCurta);
      CopyBuffer(handlemedialonga,0,0,2,mediaLonga);
      
      //compra
      if(mediaCurta[1] <= mediaLonga[1] && mediaCurta[0] > mediaLonga[0] ){
      
         return 1;      
      }            
      //venda
      if(mediaCurta[1] >= mediaLonga[1] && mediaCurta[0] < mediaLonga[0] ){
      
         return -1;
      }      
      return 0;
   }   
  
   double DistanciaCruzamento(){
   
      double soma = 0;
      double resultado = 0;
         
      for(int i= 1 ; i <= periodoCurto; i++ ){
         soma += rates[i].close;      
      }      
      resultado = soma/periodoCurto;
      
      return resultado;
   }
   
    
    void Breakeven(double preco)
      {     
      
         for(int i=PositionsTotal()-1; i>=0; i--)
            {
      
               string symbol = PositionGetSymbol(i);
               ulong magic = PositionGetInteger(POSITION_MAGIC);     
               if(symbol == _Symbol && magic == magicNum)
                  {
            
                     ulong positionTicket = PositionGetInteger(POSITION_TICKET);
                     double precoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
                     double takeProfitCorrente = PositionGetDouble(POSITION_TP);
                     if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                        {
                           if(preco >= (precoEntrada + gatilhoBE))
                              {
                                 if(trade.PositionModify(positionTicket,precoEntrada,takeProfitCorrente))
                                    {
                                       Print("Breakeven sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                                       beAtivo = true;
                                    }
                                 else
                                    {
                                          Print("Breakeven com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                                    }
                              }
                         }                  
                     else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                        {
                           if(preco <= (precoEntrada - gatilhoBE))
                              {
                                 if(trade.PositionModify(positionTicket,precoEntrada,takeProfitCorrente))
                                    {
                                       Print("Breakeven sem falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                                       beAtivo = true;
                                    }
                                 else
                                    {
                                          Print("Breakeven com falha. ResultRetCode: ", trade.ResultRetcode(), "ResultRetCode description: ", trade.ResultRetcodeDescription());
                                    }   
                                }
                        }  
                   }
               }
       }