//+------------------------------------------------------------------+
//|                CandlestickPatternEA.mq4                          |
//|       Détecte les figures de chandeliers et place des ordres     |
//+------------------------------------------------------------------+
#property copyright "Votre Nom"
#property link      "Votre Site Web"
#property version   "1.00"
#property strict

//--- Paramètres de l'EA
double LotSize = 0.1;            // Taille du lot
input int Slippage = 3;                // Glissement
input int StopLoss = 3500;             // Stop Loss en pips
input int TakeProfit = 1500;              // Take Profit en pips
input int TrailingStop = 3000;         // Trailing Stop en pips
input int RSIPeriod = 14;              // Période du RSI
input double RSIOverbought = 70.0;     // Niveau de surachat du RSI
input double RSIOversold = 30.0;       // Niveau de survente du RSI
double protection1 = 0;
double protection2 = 0;
//--- Variables globales
bool TrendUp = false;
bool TrendDown = false;
int MagicNumber = 12345;               // Magic Number de l'EA
double rsiValue;
input double StochOverbought = 70.0;   // Niveau de surachat du Stochastique
input double StochOversold = 30.0;     // Niveau de survente du Stochastique
input int StochKPeriod = 14;           // Période %K du Stochastique
input int StochDPeriod = 3;            // Période %D du Stochastique
input int StochSlowing = 3;            // Slowing du Stochastique
double stochKValue;
double stochDValue;


// Variables globales
double tenkan, kijun, senkouSpanA, senkouSpanB,chikounspan;
double senkouSpanA_future, senkouSpanB_future;
double cloudTop, cloudBottom;
bool chikounspan_buy = false;
bool chikounspan_sell = false;
double tenkan26, kijun26, senkouSpanA26, senkouSpanB26, cloudTop26, cloudBottom26;


// Fonction pour calculer l'Ichimoku
void CalculateIchimoku(int shift) {
   tenkan = iIchimoku(NULL, 0, 9, 26, 52, MODE_TENKANSEN, shift);
   kijun = iIchimoku(NULL, 0, 9, 26, 52, MODE_KIJUNSEN, shift);
   senkouSpanA = iIchimoku(NULL, 0, 9, 26, 52, MODE_SENKOUSPANA, shift);
   senkouSpanB = iIchimoku(NULL, 0, 9, 26, 52, MODE_SENKOUSPANB, shift);
   tenkan26 = iIchimoku(NULL, 0, 9, 26, 52, MODE_TENKANSEN, 27);
   kijun26 = iIchimoku(NULL, 0, 9, 26, 52, MODE_KIJUNSEN, 27);
   senkouSpanA26 = iIchimoku(NULL, 0, 9, 26, 52, MODE_SENKOUSPANA, 27);
   senkouSpanB26 = iIchimoku(NULL, 0, 9, 26, 52, MODE_SENKOUSPANB, 27);
   cloudTop26 = MathMax(senkouSpanA26, senkouSpanB26);
   cloudBottom26 = MathMin(senkouSpanA26, senkouSpanB26);
   cloudTop = MathMax(senkouSpanA, senkouSpanB);
   cloudBottom = MathMin(senkouSpanA, senkouSpanB);
   chikounspan = iIchimoku(NULL, 0, 9, 26, 52, MODE_CHIKOUSPAN, 27);
   
   chikounspan_buy = chikounspan > tenkan26 && chikounspan > kijun26 && chikounspan > cloudTop26 && chikounspan > Close[26];
   chikounspan_sell = chikounspan < tenkan26 && chikounspan < kijun26 && chikounspan < cloudBottom26 && chikounspan < Close[26];
   
}
//+------------------------------------------------------------------+
//| Fonction d'initialisation de l'EA                                |
//+------------------------------------------------------------------+
int OnInit()
  {
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Fonction principale de l'EA                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Ajuster LotSize en fonction du solde du compte
   LotSize = NormalizeDouble((AccountBalance() / 10000) * 0.1, 2);
   if (LotSize > 10.0)
     LotSize = 10.0;

   // Gérer le trailing stop si un ordre est ouvert
   if(OrdersTotal() > 0)
     {
      ManageTrailingStop();
     }

   // Détecter la tendance sur les 52 dernières bougies
   DetectTrend();
   CalculateIchimoku(1);
   // Obtenir la valeur actuelle du RSI
   rsiValue = iRSI(Symbol(), Period(), RSIPeriod, PRICE_CLOSE, 1);

   // Obtenir la valeur actuelle du Stochastique
   stochKValue = iStochastic(Symbol(), Period(), StochKPeriod, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_MAIN, 1);
   stochDValue = iStochastic(Symbol(), Period(), StochKPeriod, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_SIGNAL, 1);

   // Détecter les figures de chandeliers
   string pattern = DetectCandlestickPattern();

   // Passer des ordres en fonction du pattern détecté, de la tendance, du RSI et du Stochastique
   PlaceOrder(pattern, rsiValue, stochKValue, stochDValue);
  }


//+------------------------------------------------------------------+
//| Fonction de gestion du Trailing Stop                             |
//+------------------------------------------------------------------+
void ManageTrailingStop()
  {
   double point = MarketInfo(Symbol(), MODE_POINT);
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * point;
   double Bid = MarketInfo(Symbol(), MODE_BID);
   double Ask = MarketInfo(Symbol(), MODE_ASK);

   for(int cnt=0; cnt<OrdersTotal(); cnt++)
     {
      if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
        {
         // Vérifier si l'ordre appartient à cet EA
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
           {
            if(OrderType() == OP_BUY)
              {
               // Vérifier si le profit est supérieur au TrailingStop
               if(Bid - OrderOpenPrice() > TrailingStop * point)
                 {
                  double newStopLoss = Bid - TrailingStop * point;
                  newStopLoss = NormalizeDouble(newStopLoss, Digits);

                  // Si le nouveau SL est supérieur à l'ancien, le modifier
                  if(OrderStopLoss() < newStopLoss || OrderStopLoss() == 0)
                    {
                     // Vérifier que le nouveau SL est à une distance acceptable du prix actuel
                     if((Bid - newStopLoss) >= stopLevel)
                       {
                        bool result = OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrGreen);
                       }
                    }
                 }
              }
            else if(OrderType() == OP_SELL)
              {
               // Vérifier si le profit est supérieur au TrailingStop
               if(OrderOpenPrice() - Ask > TrailingStop * point)
                 {
                  double newStopLoss = Ask + TrailingStop * point;
                  newStopLoss = NormalizeDouble(newStopLoss, Digits);

                  // Si le nouveau SL est inférieur à l'ancien, le modifier
                  if(OrderStopLoss() > newStopLoss || OrderStopLoss() == 0)
                    {
                     // Vérifier que le nouveau SL est à une distance acceptable du prix actuel
                     if((newStopLoss - Ask) >= stopLevel)
                       {
                        bool result = OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrRed);
                       }
                    }
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Fonction de détection de la tendance                             |
//+------------------------------------------------------------------+
void DetectTrend()
  {
   // Votre code existant pour la détection de la tendance
   // (inchangé)
  }

//+------------------------------------------------------------------+
//| Fonction de détection des figures de chandeliers                 |
//+------------------------------------------------------------------+
string DetectCandlestickPattern()
  {
   // Variables pour les calculs

   // Barres utilisées :
   // i = 1 : Bougie actuelle (dernière clôturée)
   // i = 2 : Bougie précédente
   // i = 3 : Bougie précédente de la précédente

   // Bougie 1
   double Open1 = iOpen(Symbol(), Period(), 1);
   double Close1 = iClose(Symbol(), Period(), 1);
   double High1 = iHigh(Symbol(), Period(), 1);
   double Low1 = iLow(Symbol(), Period(), 1);

   // Bougie 2
   double Open2 = iOpen(Symbol(), Period(), 2);
   double Close2 = iClose(Symbol(), Period(), 2);
   double High2 = iHigh(Symbol(), Period(), 2);
   double Low2 = iLow(Symbol(), Period(), 2);

   // Bougie 3
   double Open3 = iOpen(Symbol(), Period(), 3);
   double Close3 = iClose(Symbol(), Period(), 3);
   double High3 = iHigh(Symbol(), Period(), 3);
   double Low3 = iLow(Symbol(), Period(), 3);

   // Calcul des corps et des ombres
   double Body1 = MathAbs(Close1 - Open1);
   double Body2 = MathAbs(Close2 - Open2);
   double Body3 = MathAbs(Close3 - Open3);

   double UpperShadow1 = High1 - MathMax(Open1, Close1);
   double LowerShadow1 = MathMin(Open1, Close1) - Low1;

   double UpperShadow2 = High2 - MathMax(Open2, Close2);
   double LowerShadow2 = MathMin(Open2, Close2) - Low2;

   double UpperShadow3 = High3 - MathMax(Open3, Close3);
   double LowerShadow3 = MathMin(Open3, Close3) - Low3;

   // Moyenne des corps et ombres pour référence
   double avgBody = AverageBodySize();
   double avgShadow = AverageShadowSize();

   // Détection des patterns

   // --- Avalement haussier (Bullish Engulfing) ---
   if(Close2 < Open2 && Close1 > Open1 &&
      Open1 <= Close2 && Close1 >= Open2 &&
      Body1 > Body2 * 1.0) // Le corps de la bougie 1 est plus grand que celui de la bougie 2
     {
      return "BullishEngulfing";
     }

   // --- Avalement baissier (Bearish Engulfing) ---
   if(Close2 > Open2 && Close1 < Open1 &&
      Open1 >= Close2 && Close1 <= Open2 &&
      Body1 > Body2 * 1.0) // Le corps de la bougie 1 est plus grand que celui de la bougie 2
     {
      return "BearishEngulfing";
     }

   // --- Couverture en nuage noir (Dark Cloud Cover) ---
   if(Close2 > Open2 && Open1 > Close2 &&
      Close1 < (Open2 + Close2) / 2 && Close1 > Open2)
     {
      return "DarkCloudCover";
     }

   // --- Pénétrante (Piercing Line) ---
   if(Close2 < Open2 && Open1 < Close2 &&
      Close1 > (Open2 + Close2) / 2 && Close1 < Open2)
     {
      return "PiercingLine";
     }

   // --- Harami haussier (Bullish Harami) ---
   if(Close2 < Open2 && Close1 > Open1 &&
      Open1 > Close2 && Close1 < Open2)
     {
      return "BullishHarami";
     }

   // --- Harami baissier (Bearish Harami) ---
   if(Close2 > Open2 && Close1 < Open1 &&
      Open1 < Close2 && Close1 > Open2)
     {
      return "BearishHarami";
     }

   // --- Étoile du matin (Morning Star) ---
   if(Close3 < Open3 &&                          // Bougie 3 baissière
      MathAbs(Close2 - Open2) <= avgBody * 0.5 && // Bougie 2 petit corps (étoile)
      Close1 > Open1 &&                          // Bougie 1 haussière
      Close1 > (Open3 + Close3) / 2)             // Bougie 1 clôture au-dessus du milieu de la bougie 3
     {
      return "MorningStar";
     }

   // --- Étoile du soir (Evening Star) ---
   if(Close3 > Open3 &&                          // Bougie 3 haussière
      MathAbs(Close2 - Open2) <= avgBody * 0.5 && // Bougie 2 petit corps (étoile)
      Close1 < Open1 &&                          // Bougie 1 baissière
      Close1 < (Open3 + Close3) / 2)             // Bougie 1 clôture en dessous du milieu de la bougie 3
     {
      return "EveningStar";
     }

   // --- Patterns existants (Hammer, Shooting Star, etc.) ---

   // Exemple pour le Hammer (Marteau)
   if(Body1 <= avgBody * 0.75 &&
      LowerShadow1 >= avgShadow * 1.5 &&
      UpperShadow1 <= avgShadow * 0.5)
     {
      if(TrendDown)
        return "Hammer";
     }

   // Exemple pour le Shooting Star (Étoile filante)
   if(Body1 <= avgBody * 0.75 &&
      UpperShadow1 >= avgShadow * 1.5 &&
      LowerShadow1 <= avgShadow * 0.5)
     {
      if(TrendUp)
        return "ShootingStar";
     }

   // Autres patterns (Inverted Hammer, Hanging Man, Doji, High Wave)
   // (inchangés ou à ajuster selon les besoins)

   // Si aucun pattern n'est détecté
   return "None";
  }

//+------------------------------------------------------------------+
//| Fonction pour calculer la taille moyenne du corps des bougies    |
//+------------------------------------------------------------------+
double AverageBodySize()
  {
   double total = 0;
   for(int i = 1; i <= 10; i++)
     {
      double Open = iOpen(Symbol(), Period(), i);
      double Close = iClose(Symbol(), Period(), i);
      total += MathAbs(Close - Open);
     }
   return total / 10;
  }

//+------------------------------------------------------------------+
//| Fonction pour calculer la taille moyenne des mèches              |
//+------------------------------------------------------------------+
double AverageShadowSize()
  {
   double total = 0;
   for(int i = 1; i <= 10; i++)
     {
      double Open = iOpen(Symbol(), Period(), i);
      double Close = iClose(Symbol(), Period(), i);
      double High = iHigh(Symbol(), Period(), i);
      double Low = iLow(Symbol(), Period(), i);

      double UpperShadow = High - MathMax(Open, Close);
      double LowerShadow = MathMin(Open, Close) - Low;

      total += (UpperShadow + LowerShadow);
     }
   return total / (10 * 2); // Divisé par 2 pour avoir la moyenne des deux mèches
  }

//+------------------------------------------------------------------+
//| Fonction pour détecter la structure en haute vague               |
//+------------------------------------------------------------------+
bool IsHighWave()
  {
   int count = 0;
   for(int i = 1; i <= 3; i++)
     {
      double Open = iOpen(Symbol(), Period(), i);
      double Close = iClose(Symbol(), Period(), i);
      double High = iHigh(Symbol(), Period(), i);
      double Low = iLow(Symbol(), Period(), i);

      double Body = MathAbs(Close - Open);
      double UpperShadow = High - MathMax(Open, Close);
      double LowerShadow = MathMin(Open, Close) - Low;

      double avgBody = AverageBodySize();
      double avgShadow = AverageShadowSize();

      if(Body <= avgBody * 0.5 && UpperShadow >= avgShadow && LowerShadow >= avgShadow)
         count++;
     }

   if(count >= 2)
      return true;
   else
      return false;
  }

//+------------------------------------------------------------------+
//| Fonction pour passer des ordres                                  |
//+------------------------------------------------------------------+
void PlaceOrder(string pattern, double rsiValue, double stochKValue, double stochDValue)
  {
   // Calculer le prix Stop Loss et Take Profit
   double point = MarketInfo(Symbol(), MODE_POINT);
   double SL, TP;

   // Vérifier si un ordre d'achat est déjà ouvert
   bool buyOrderOpen = IsOrderTypeOpen(OP_BUY);

   // Vérifier si un ordre de vente est déjà ouvert
   bool sellOrderOpen = IsOrderTypeOpen(OP_SELL);

   // Vérifier les conditions pour un ordre d'achat
   if(
      (pattern == "Hammer" || pattern == "InvertedHammer" || pattern == "HighWave" || pattern == "BullishEngulfing" || pattern == "PiercingLine" || pattern == "BullishHarami" || pattern == "MorningStar") &&
      stochKValue < StochOversold &&
      stochDValue < StochOversold && protection1 != Close[1] && kijun > cloudTop && tenkan > cloudTop && chikounspan_buy && tenkan > kijun)
     {
      SL = Bid - StopLoss * point;
      TP = 0;
      double TP1 = Bid + 1500 * point;
      double TP2 = Bid + 2000 * point;
      double TP3 = Bid + 2500 * point;
      double TP4 = Bid + 3000 * point;
      double TP5 = Bid + 1000 * point;
      double TP6 = Bid + 500 * point;
      protection1 = Close[1];
      OrderSend(Symbol(), OP_BUY, LotSize, Ask, Slippage, SL, TP, "Buy Order", MagicNumber, 0, clrGreen);
      OrderSend(Symbol(), OP_BUY, LotSize, Ask, Slippage, SL, TP1, "Buy Order", MagicNumber, 0, clrGreen);
      OrderSend(Symbol(), OP_BUY, LotSize, Ask, Slippage, SL, TP2, "Buy Order", MagicNumber, 0, clrGreen);
      OrderSend(Symbol(), OP_BUY, LotSize, Ask, Slippage, SL, TP3, "Buy Order", MagicNumber, 0, clrGreen);
      OrderSend(Symbol(), OP_BUY, LotSize, Ask, Slippage, SL, TP4, "Buy Order", MagicNumber, 0, clrGreen);
      OrderSend(Symbol(), OP_BUY, LotSize, Ask, Slippage, SL, TP5, "Buy Order", MagicNumber, 0, clrGreen);
      OrderSend(Symbol(), OP_BUY, LotSize, Ask, Slippage, SL, TP6, "Buy Order", MagicNumber, 0, clrGreen);
     }
   // Vérifier les conditions pour un ordre de vente
   if(
      (pattern == "ShootingStar" || pattern == "HangingMan" || pattern == "HighWave" || pattern == "BearishEngulfing" || pattern == "DarkCloudCover" || pattern == "BearishHarami" || pattern == "EveningStar") &&
      stochKValue > StochOverbought &&
      stochDValue > StochOverbought && protection2 != Close[1] && kijun < cloudBottom && tenkan < cloudBottom && chikounspan_sell && tenkan < kijun)
     {
      SL = Ask + StopLoss * point;
      TP = 0;
      double TP1 = Ask - 1500 * point;
      double TP2 = Ask - 2000 * point;
      double TP3 = Ask - 2500 * point;
      double TP4 = Ask - 3000 * point;
      double TP5 = Ask - 1000 * point;
      double TP6 = Ask - 500 * point;
      protection2 = Close[1];
      OrderSend(Symbol(), OP_SELL, LotSize, Bid, Slippage, SL, TP, "Sell Order", MagicNumber, 0, clrRed);
      OrderSend(Symbol(), OP_SELL, LotSize, Bid, Slippage, SL, TP1, "Sell Order", MagicNumber, 0, clrRed);
      OrderSend(Symbol(), OP_SELL, LotSize, Bid, Slippage, SL, TP2, "Sell Order", MagicNumber, 0, clrRed);
      OrderSend(Symbol(), OP_SELL, LotSize, Bid, Slippage, SL, TP3, "Sell Order", MagicNumber, 0, clrRed);
      OrderSend(Symbol(), OP_SELL, LotSize, Bid, Slippage, SL, TP4, "Sell Order", MagicNumber, 0, clrRed);
      OrderSend(Symbol(), OP_SELL, LotSize, Bid, Slippage, SL, TP5, "Sell Order", MagicNumber, 0, clrRed);
      OrderSend(Symbol(), OP_SELL, LotSize, Bid, Slippage, SL, TP6, "Sell Order", MagicNumber, 0, clrRed);
     }
  }


//+------------------------------------------------------------------+
//| Fonction pour vérifier si un type d'ordre est déjà ouvert        |
//+------------------------------------------------------------------+
bool IsOrderTypeOpen(int orderType)
  {
   for(int cnt=0; cnt<OrdersTotal(); cnt++)
     {
      if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
           {
            return true;
           }
        }
     }
   return false;
  }
