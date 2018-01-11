libname stocks "C:\Users\amodi8\Desktop\SAS Final Project\Stocks";

proc contents data=stocks.Annualreports varnum;
run;

proc freq data=stocks.Annualreports;
table IndFinancialYearEnd;
run;

data stocks.No2014;
set stocks.Annualreports;
FiscalYearDate=datepart(IndFinancialYearEnd);
FiscalYear=Year(FiscalYearDate);
if FiscalYearDate<"1Jan2014"d;
run;

proc freq data=stocks.No2014;
table FiscalYear;
run;

proc freq data=stocks.No2014;
tables sector*industry/list missing missprint;
run;

*sector="Technology" and industry="Semiconductors"; 

data MyCompanies;
set stocks.No2014;
if sector="Technology" and industry="Semiconductors";
run;

proc freq data=Mycompanies order=freq;
title "Number of Annual Report Records by Name";
table Name;
run;
title;

proc freq data=Mycompanies;
title "Counts of Symbol by Name--Detect Duplicates";
table Symbol*Name/list missing missprint;
run;
title;

proc sort nodupkey data=myCompanies;
by name FiscalYear;
run;

proc freq data=Mycompanies;
title "Counts of Symbol by Name--Detect Duplicates";
table Symbol*Name/list missing missprint;
run;
title;

data MyCompanies;
set MyCompanies;
NameCompressed=compress(Name, " .(),#-;");
run;

proc freq data=Mycompanies order=freq;
tables NameCompressed/list out=CompanyCounts;
title "Counts of Symbol by Name--Detect Duplicates";
run;
title;

data WithBinaries;
set MyCompanies;
if NameCompressed="AdvancedMicroDevicesInc" then AdvancedMicroDevicesInc=1;
									 		else AdvancedMicroDevicesInc=0;
if NameCompressed="AdvancedPhotonixInc" then AdvancedPhotonixInc=1;
									 	else AdvancedPhotonixInc=0;
if NameCompressed="AlteraCorporation" then AlteraCorporation=1;
									  else AlteraCorporation=0;
if NameCompressed="AnalogDevicesInc" then AnalogDevicesInc=1;
									 else AnalogDevicesInc=0;
run;

proc freq data=WithBinaries order=freq;
tables Name*AdvancedMicroDevicesInc*AdvancedPhotonixInc*AlteraCorporation*AnalogDevicesInc/list nopercent nocum missing missprint;
run;

data ForAnova;
set WithBinaries;
if AdvancedMicroDevicesInc=1 or AdvancedPhotonixInc=1 or AlteraCorporation=1 or AnalogDevicesInc=1;
run;

data ConvertMetric;
set ForAnova;
ROEToInd=input(ROEToIndustry,8.);
run;

proc means data=ConvertMetric;
class symbol;
var ROEToInd;
run;

proc anova data=ConvertMetric;
class symbol;
model ROEToInd=symbol;
means symbol/snk;
run;
quit;

proc sort nodupkey data=myCompanies;
by symbol;
run;

*Method 1: Merge MyCompanies and OptionsFile;
data work.OptionsFile;
set stocks.OptionsFile (rename=(underlying=Symbol));
if "01Feb2014"d<=expdate<="31Oct2014"d;
run;

proc sort data=OptionsFile;
by Symbol expdate strike;
run;

data MyOptions;
merge MyCompanies (in=OnCompanies keep=symbol)
	  work.OptionsFile(in=OnOptions);
by Symbol;
if OnCompanies and OnOptions;
run;

*Method 2: Merge MyCompanies and OptionsFile;
proc sort data=stocks.OptionsFile;
by underlying expdate strike;
run;

data MyOptions;
merge MyCompanies (in=OnCompanies keep=symbol)
	  stocks.OptionsFile(in=OnOptions rename=(underlying=Symbol));
by Symbol;
if 	OnCompanies and OnOptions and
	"01Feb2014"d<=expdate<="31Oct2014"d;
run;

proc freq data=MyOptions;
table Symbol;
run;

proc means data=MyOptions;
class Symbol type;
var strike;
run;

proc summary data=MyOptions nway;
class Symbol type;
var strike;
output out=OptionStrikes mean=;
run;

data prices;
set stocks.Prices;
year=year(date);
month=month(date);
run;

proc means data=work.prices n nmiss min;
class year;
var date;
run;

proc summary data=work.prices nway;
class year;
var date;
output out=FirstTradingDayPerYear min=;
run;

proc print data=FirstTradingDayPerYear;
run;

data Jans;
set prices;
if month=1;
run;

proc freq data=Jans;
tables date;
run;

data MyFirstTradingDay;
set stocks.prices;
if date="03Jan2012"d;
run;

proc sort data=MyFirstTradingDay;
by tic;
run;

data MyPriceFirstTradingDay;
merge MyCompanies (in=OnCompanies keep=symbol)
	  MyFirstTradingDay(in=OnPrices rename=(tic=symbol));
by Symbol;
if OnCompanies and OnPrices;
run;

data work.DivFile;
set stocks.DivFile;
where Date ge "03Jan2012"d;
rename tic=symbol;
run;

data MyDividends;
merge 	MyPriceFirstTradingDay 	(in=OnPrice)
		DivFile					(in=OnDiv);
by symbol;
if OnPrice and OnDiv;
run;

proc summary data=MyDividends nway;
class symbol adjclose;
var DivAmount;
output out=DivSum sum=;
run;

data DivCalc;
format DivYield percent8.1;
set DivSum;
DivYield=DivAmount/AdjClose;
run;

data work.Splits(drop=date rename=(splitdate=date));
set stocks.Splits;
SplitDate = input (date,YYMMDD10.);
format SplitDate YYMMDD10.;
rename tic=symbol;
run;

data MySplits;
merge 	MyCompanies (in=OnCompanies keep=symbol)
		Splits		(in=OnSplits);
by symbol;
if 	OnCompanies and OnSplits
	and date ge "02Jan1990"d;
run;

proc means data=MySplits max min;
class Symbol;
var split;
output out=SplitMinMax(drop=_type_) min=SplitMin max=SplitMax;
run;

data OnePerSymbolStart;
merge 	MyCompanies	(in=OnBase keep=symbol)
		SplitMinMax (in=OnSplits)
		DivCalc		(in=OnDiv);
by symbol;
if OnBase;
run;

proc freq data=MyOptions noprint;
table Symbol /out=OptionsCount (drop=Percent rename=(count=OptionsCount));
run;

proc transpose 	data=OptionStrikes (drop=_type_ _freq_)
				out=OptionsTransposed Prefix=StrikePrice_;
	by symbol; id type; var strike;
run;

data OnePerSymbolRound2;
merge 	MyCompanies	(in=OnBase keep=symbol)
		SplitMinMax (in=OnSplits rename=(_freq_=SplitCount))
		DivCalc		(in=OnDiv drop=_type_ _freq_ adjclose)
		OptionsCount (in=OnOptions)
		OptionsTransposed (in=OptionsPrices drop=_NAME_);
by symbol;
if OnBase;
run;

data 	OnePerSymbolNoBlanks;
set 	OnePerSymbolRound2;
format StrikePrice_C StrikePrice_P 8.2;
array numbervars _numeric_;
do over numbervars;
	if numbervars=. then numbervars=0;
end;
run;

data 	OnePerSymbolNoBlanks;
set 	OnePerSymbolRound2;
format StrikePrice_C StrikePrice_P 8.2;
array BlankToZero SplitCount DivYield DivAmount OptionsCount;
do over BlankToZero;
	if BlankToZero=. then BlankToZero=0;
end;
run;

*Calculate Return on Capital (ROC) and rank within sector="Technology" and industry="Semiconductors";
data MyCompany;
set stocks.Annualreports;
format InfoAvailDate YYMMDD10.;
where sector="Technology" and industry="Semiconductors";
FiscalYearDate=datepart(IndFinancialYearEnd);
FiscalYear=Year(FiscalYearDate);
InfoAvailDate=input(IndDatePrelimLoaded,YYMMDD10.);
run;

proc sort data=MyCompany nodupkey;
by symbol IndFinancialYearEnd;
run;

data Report2009;
	set MyCompany (keep=	FiscalYear EBIT BSTotalCurrentLiabilities BSLTDebt BSMinorIntLiab BSPrefStockEq
							BSCash BSNetFixedAss BSWC symbol InfoAvailDate BSSharesOutCommon);
	where FiscalYear=	2009;
	ReturnOnCapital=	EBIT/(BSNetFixedAss+BSWC);
run;

proc rank data=report2009 out=Report2009ROC descending;
var ReturnOnCapital;
ranks RankROC;
run;

*Determine Earnings Yield for cut-off year. Need market cap, so need price on
	date annual report was released;

data GetPrices;
merge 	Report2009ROC	(in=OnBase)
		stocks.prices	(in=OnPrices rename=(tic=symbol) keep=tic date close adjclose);
by symbol;
if OnBase and date=InfoAvailDate;
run;

proc freq data=GetPrices;
tables Symbol;
title "GetPrices";
run;
title;

data GetPrices2;
merge 	Report2009ROC	(in=OnBase)
		stocks.prices	(in=OnPrices rename=(tic=symbol) keep=tic date close adjclose);
by symbol;
if OnBase and InfoAvailDate<=date<=InfoAvailDate+5;
run;

proc freq data=GetPrices2;
tables Symbol;
title "GetPrices2";
run;
title;

data GetPricesFirst;
set GetPrices2;
by symbol date;
if first.symbol;
run;

data EarningsYield;
set GetPricesFirst;
MarketCap=close*BSSharesOutCommon;
EarningsYield=	EBIT / (MarketCap + BSTotalCurrentLiabilities + BSLTDebt + BSMinorIntLiab + BSPrefStockEq - BSCash); 
run;

proc rank data=EarningsYield out=EYAndROCRank descending;
var EarningsYield;
ranks RankEY;
run;

proc plot data=EYAndROCRank;
plot RankEY*RankROC=' ' $symbol;
run;
quit;

data AvgRank;
set EYAndROCRank;
AvgRank=(RankEY + RankROC) / 2;
run;

data MyCompaniesOneYearLater (keep=symbol FiscalYear InfoAvailDate);
set stocks.Annualreports;
format InfoAvailDate YYMMDD10.;
where sector="Technology" and industry="Semiconductors";
FiscalYearDate=datepart(IndFinancialYearEnd);
FiscalYear=Year(FiscalYearDate);
InfoAvailDate=input(IndDatePrelimLoaded,YYMMDD10.);
if FiscalYear = 2010;
run;

data OneYearLaterWithPrice;
merge 	MyCompaniesOneYearLater	(in=OnCompanies)
		stocks.prices	(in=OnPrices rename=(tic=symbol adjclose=LaterAdjClose) keep=tic date close adjclose);
by symbol;
if InfoAvailDate-5<=date<=InfoAvailDate-1;
run;

data PriceBeforeNextReport;
set OneYearLaterWithPrice;
by symbol date;
if last.symbol;
run;

data EvalBeforeNextReport;
merge 	AvgRank (in=OnBase)
		PriceBeforeNextReport (in=OnNext);
by	symbol;
if OnBase;
return=(LaterAdjClose-AdjClose)/AdjClose;
run;

proc plot data=EvalBeforeNextReport;
plot return*AvgRank=' ' $symbol;
run;
quit;

data MuchLaterPrice (keep=tic adjclose rename=(tic=symbol adjclose=adjclose2014));
set stocks.prices;
if date="02Jan2014"d;
run;

data LaterReturn;
merge 	EvalBeforeNextReport (in=OnBase)
		MuchLaterPrice (in=OnLater);
by	symbol;
if OnBase;
return2014=(AdjClose2014-AdjClose)/AdjClose;
run;

proc plot data=LaterReturn;
plot return2014*AvgRank=' ' $symbol;
run;
quit;

proc reg data=LaterReturn;
model return2014=AvgRank;
run;
quit;

proc reg data=LaterReturn;
model return=AvgRank;
run;
quit;
