*  An example of using the mycstlink macro;

** Note: this does not merge delisting returns, but is an illustration of how to;
** merge Compustat and CRSP and compute returns with monthly data;

* The macro should be loaded before it can be run.  You can copy and paste ;
* it in your autoexec.sas file in your wrds home directory, or save it separately;
* (e.g. /home/yourschool/yourname/macros/_mycstlink.sas);
* and include it in your autoexec.sas file as follows;
* %include "/home/yourschool/yourname/macros/_mycstlink.sas";

options ls=125;

* Now that the macro is loaded, run it;
%mycstlink(preslack=180,slack=180);

* Create a Compustat dataset for fiscal year 2000, and date ranges for 12 month;
* returns starting 4 months after fiscal year-end;
* Note, the statement "input(gvkey,6.) as gvkey" converts the character format to number format;
proc sql;
    create table sample as
	select gvkey, fyear, fyr, at, datadate,
	intnx("MONTH",datadate,5,"BEG") as begret format mmddyy8., intnx("MONTH",datadate,16,"END") as endret format mmddyy8.
	from compna.funda
	where indfmt="INDL" and datafmt='STD' and popsrc='D' and consol='C' and curcd="USD" and at>0
	and fyear=2000 and input(gvkey,6.) < 2000; * limit it to a small number of firms since this is just an example;

    create table sample as
	select a.*, b.lpermno as permno, b.linkdt, b.extlinkenddt
	from sample a left join mycstlink b
	on a.GVKEY=b.GVKEY
	where b.linkdt <= a.datadate <= b.extlinkenddt;

    select * from _last_;

* the above merge with mycstlink does not allow any preslack, but allows;
* slack (after) to extend as far as possible;
* The variables can change depending on how you want to use the mycstlink data;
* such as:   c.extlinkdt <= x.crsplinkdate <= c.extlinkenddt;
*            c.slinkdt <= x.crsplinkdate <= c.slinkenddt;

proc sql;
    create table temp as 
	select a.*, b.ret, b.date as crspdate
	from sample a left join crsp.msf b
	on (a.permno = b.permno) and (a.begret <= b.date <= a.endret);
        * and (a.linkdt <= b.date <= a.extlinkenddt);
           *Optinal restriction: to check every CRSP observation that the return date is in the range;
             * Note, the merge could be done without the (a.linkdt <= b.date <= a.linkenddt);
             * restriction. There is a small possibility of merging security prices that;
             * are linked to another gvkey;

    select * from _last_;


proc sql;
    create table sample_returns as
	select gvkey, permno, datadate, exp(sum(log(1+ret)))-1 as ret, n(ret) as nret
	from temp
	group by gvkey, permno, datadate;

    select * from _last_;

    create table sample as
	select a.*, b.ret, b.nret
	from sample a left join sample_returns b
	on a.gvkey=b.gvkey and a.permno=b.permno and a.datadate=b.datadate;
    
    select * from _last_;
	
