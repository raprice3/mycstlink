/*
 * Macro mycstlink
 * Created by Richard Price
 * Updated January 2005
 * 
 * This macro takes the cstlink from ccm database and addresses two important issues
 * for computing returns
 *        1) The cstlink file contains several records for which the GVKEY-PERMNO
 *           link is broken down into several subperiods, This can cause problems
 *           when merging with compustat because we want the entire range over which
 *           a GVKEY-PERMNO link is effective and not just subintervals.
 *           The first part of this macro combines subintervals into one interval.
 *           For example consider GVKEY 5313:
 *           linkdt     linkenddt    NPERMNO
 *           19720101   19761230     12175
 *           19761231   19761231     12175
 *           19770101   19770330     12175
 *           19770331          .     12175
 *          
 *           Clearly the effective range for this gvkey-permno match is 19720101 to "."
 *           But cstlink breaks this down into several subperiods
 * 
 *        2) The link between PERMNO and GVKEY is a many to many relationship.
 *           A GVKEY may be related to different PERMNOs over its history.  Likewise
 *           a PERMNO may be assigned to different GVKEYS (sometimes the range is
 *           overlapping in this second case).  Both of these issues must be dealt 
 *           with separately.
 *
 *           Of particular interest is allowing slack in the cstlink file.
 *           Slack should not be allowed when 
 *             a) the GVKEY is related to another PERMNO after the current effective period 
 *             b) the PERMNO is related to another GVKEY after the current period 
 *
 *                   PERMNO 30278 MATCHES TO GVKEY 5199 FROM 19820406 TO 19831227
 *                   AND TO GVKEY 3998 FROM 19831228 TO 19850911.
 *                   GVKEY 3998 SHOWS NO PERMNO MATCHES PRIOR TO 19831228,
 *                   IF ONLY THE RELATION GOING FROM GVKEY TO PERMNO IS CONSIDERED THEN
 *                   SLACK FOR GVKEY 3998 WILL ALLOW RETURNS FOR PERMNO 30278 THAT
 *                   BELONG TO GVKEY 5199 (WHICH IS ASSIGNED TO 5199 PRIOR TO 
 *                   19831228).
 *
 *        3) Regarding the GVKEY-PERMNO match. This macro determines the maximum amount of
 *           preslack and slack to allow based on if the gvkey was assigned to another permno
 * 
 *        4) Point 3 above relates to the link from GVKEY to PERMNO.  This code also determines
 *           the maximum amount of preslack and slack to allow based on if the permno was assigned
 *           to another gvkey  before or after the current link period.
 *
 *        5) Page 16 of the ccm manual states:
 * 
 *    Only researched date ranges are included in the link history. If the CRSP
 *    data extends before or after the Compustat data for a company, the last
 *    known PERMNO can be used to identify the issue. A researched disconnection
 *    between the CRSP and Compustat records is also indicated with a link event
 *    by a zero in the NPERMNO field. For additional detail on the reason there
 *    is no link, use the LINKTYPE code with NPERMNO.
 *
 *           So this macro creates a set of linkdates, called extreme link dates
 *           extlinkdt and extlinkenddt.  If the gvkey is not assigned to another
 *           permno before the current link and if the permno is not assigned to 
 *           another gvkey before the current link, extlinkdt is set to 1/1/1950.
 *           Similarly if the gvkey is not assigned another permno after the current
 *           link and vice versa the extlinkenddt is set to . (the latest possible date)
 * 
 * Input Variables:
 *   preslack A variable indicating how many days before the linkdt to allow slack
 *      slack A variable indicating how many days after the linkenddt to allow slack
 *            There are instances in which the following occurs;
 *           linkdt     linkenddt    NPERMNO
 *           19720101   19761030         X
 *           19761031   19761231         .
 *           19770101   19770330         Y
 *  In this example (for the same GVKEY) there is no effective link after 19761030, but
 *  two months later there is an effective link to permno Y.  Thus if slack is going to
 *  be considered, it should take into account that two months later there is an effective
 *  GVKEY-PERMNO link.  This macro accounts for this issue.
 * 
 *           preslack and slack is a number in DAYS that determines whether the variables
 *           linkbef or linkaft.  THE DEFAULT IS 180 days for both.  Preslack can be positive
 *           or negative (absolute value functions are used to protect from potential errors).
 *  
 *
 *   OUTPUT: This macro creates a file in the working directory called mycstlink
 *           It is assumed that this macro will be used in conjunction with return macros
 *   VARIABLES CREATED:
 *           slinkdt: This is a link date that incorporates preslack (equals linkdt - preslack)
 *        slinkenddt: This is a link end date that incorporates slack (postslack)
 *                    This equals linkenddt + slack.
 *         extlinkdt: This equals 1/1/1950 if firstgvkey=firstpermno=1, otherwise it is the
 *                    earliest possible date
 *      extlinkenddt: This equals . if lastgvkey=lastpermno=1, otherwise it is the latest
 *                    possible date
 * 
 *  NOTE: the use of extlink and slink variables may result in some overlapping ranges
 *        because with extlinkdt and extlinkenddt the range expands as far as possible
 *        until arriving at another active link.  However that active link ext dates
 *        also expand as far as possible.  This could be addressed by allowing only
 *        max_slack_gvkey (or permno) /2 of what it is now.  I dont think it is a big deal
 *        though, so I leave it as is
 *
 */ 

%macro mycstlink(preslack=180,slack=180);

%* in case slack is ever set to null;
%if &preslack= %then %let preslack=0;
%if &slack= %then %let slack=0;

%* First accept only records without linktypes LX, LD, LF or LO (about 260 total);
%* The ccm manual suggests excluding firms with type these linktypes;
data cstlink0; 
    set crsp.cstlink;
    if linktype not in ("LX", "LD", "LF", "LO");
    if linkenddt=. then linkenddt=today();

%* there are some gvkey-permno matches where the link is inactive for a period;
%* and is then reactivated
%* dont need to do this because in line 140, I no longer restrict the time to 2 months;
%* this ended up causing duplicate overlapping linkds for the same gvkey-permno;
%*  if linkflag="XXX" and missing(npermno) then npermno=0;
    if npermno ne .;
run;
    %* nobs from 48318 to 22241;

%* ----------------------------------------------------------------------;
%* COLLAPSE EFFECTIVE RANGES WHERE THEY ARE SPREAD OUT AS DESCRIBED ABOVE;
%* in point 1 of the introduction;
%* try debugging with gvkey 5313 and 11183 and 3938 and 7466;

proc sort data=cstlink0; by gvkey linkdt; run;

data combine; format keeplinkdt date9.; 
    set cstlink0;
    by gvkey;
    npermnom1=lag(NPERMNO);
    gvkeym1  =lag(gvkey);
    linkenddtm1 =lag(linkenddt);
    retain keeplinkdt;
    
    if first.gvkey /* unnecessary and npermnom1=npermno*/ then keeplinkdt=linkdt;
    if gvkeym1=gvkey and npermnom1=npermno /* this just causes problems and 0 le intck('month',linkenddtm1,linkdt) lt 2*/ then do;
	linkdt=keeplinkdt;
	combined = 1;
    end;
    else keeplinkdt=linkdt;

    drop npermnom1 gvkeym1 linkenddtm1;
run;

proc sort data=combine; by gvkey descending linkdt descending linkenddt; run;

data cstlink0;
    set combine;
    if linkdtp1=. then linkdtp1 = today();
    npermnop1 = lag(npermno);
    linkdtp1 = lag(linkdt);

    %* This will give a value of 0 to all ranges that are superceded by the last;
    %* combined range;    
    if npermno=npermnop1 and linkdt=linkdtp1 then delete;
    drop linkdtp1 npermnop1 keeplinkdt combined;
run;

%* ----------------------------------------------------------------------;
%* Next, make sure that permno matches are not overlapping for different;
%* GVKEYs.  The compustat manual has the max rule -- whenever there is;
%* an overlapping range in the cstlink file, the GVKEY with the latest;
%* linkenddt is assigned the range, and the range of the GVKEY with the;
%* earlier linkenddt is reduced so that they do not overlap.;
%* This addresses point 4 in the introduction;

%* There are some records for which the linkenddt is the same for two;
%* GVKEYs.  In this instance I assign the latter part of the range to;
%* the GVKEY with the later linkdt.;
%* I did not see any guidance from the ccm manual for this.;

%* sm is for small;
%* create a table containing GVKEY-PERMNO matches;
proc sql;
    create table sm1 as
    select gvkey, npermno, count(GVKEY) as ct
    from cstlink0
    where npermno ne .
    group by gvkey, npermno order by npermno, gvkey;

%* next show NPERMNOs for which more than 1 unique GVKEY is assigned;
proc sql; 
    create table sm2 as
    select NPERMNO, count(GVKEY) as num_gvkey
    from sm1
    group by npermno;

%* there are 240 in oct 2004;
data sm2; 
    set sm2; 
    if num_gvkey > 1; 
run;

%* merge records from cstlink with this subset of firms;
proc sql; 
    create table sm3 as
    select sm2.*, c.*
    from sm2 left join cstlink0 as c
    on sm2.npermno=c.npermno;

%* create leads and lags of linkdt, linkenddt, npermno;
%* for fixing ranges when necessary;
proc sort data=sm3;
    by npermno descending linkdt descending linkenddt;
run;

data sm3;
     set sm3;
     npermnop1=lag(npermno);
     linkdtp1=lag(linkdt);
     linkenddtp1=lag(linkenddt);
run;
   
proc sort data=sm3;
    by npermno linkdt linkenddt;
run;

data sm3;
     set sm3;
     npermnom1=lag(npermno);
     linkdtm1=lag(linkdt);
     linkenddtm1=lag(linkenddt);
run;

%* fix the date ranges when they overlap;
data sm3;
    set sm3;
    format linkdtm1 date9. linkenddtm1 date9. linkdtp1 date9. linkenddtp1 date9.;
    if npermno = npermnop1 then do;

	%* if last part of first range overlaps with first part of last range;
	%* set the linkenddt to linkdtp1 minus 1 day so they do not overlap;
	if linkdt < linkdtp1 and linkenddt < linkenddtp1 and linkenddt > linkdtp1
	    then linkenddtnew=intnx('DAY',linkdtp1,-1);

	%* if both ranges start at the same linkdt but the second goes longer,;
	%* mark the first for deletion;
	if linkdt = linkdtp1 and linkenddt < linkenddtp1 then do;
	    linkdtnew=-50000; linkenddtnew=-50000;
	end;

        %* if ranges overlap and end on the same linkenddt, set linkenddt to;
	%* linkdt minus 1 day;
        if linkdt < linkdtp1 and linkenddt = linkenddtp1 
	    then linkenddtnew = intnx('DAY',linkdtp1,-1);

	%* if range is entirely overlapping then mark for deletion;
	%* there were no instances of this;
        if linkdt=linkdtp1 and linkenddt=linkenddtp1 then do;
            linkdtnew=-50000; linkenddtnew=-50000;
        end;
    end;   

    if npermno = npermnom1 then do;

	%* If the second range is contained entirely within the first, remove the second;
	if linkdt > linkdtm1 and linkenddt < linkenddtm1 then do;
	   linkdtnew=-50000; linkenddtnew=-50000;
	end; 

	%* if range is entirely overlapping then mark for deletion;
	%* there were no instances of this;
        if linkdt=linkdtm1 and linkenddt=linkenddtm1 then do;
            linkdtnew=-50000; linkenddtnew=-50000;
        end;
    end;

    drop npermnom1 npermnop1 linkenddtm1 linkdtm1 linkenddtp1 linkdtp1;
run;

proc sql;
    create table cstlink1 as
    select c.*, s.linkdtnew, s.linkenddtnew
    from cstlink0 as c left join sm3 as s
    on c.GVKEY=s.GVKEY and c.NPERMNO=s.NPERMNO
    and c.linkdt=s.linkdt;
       
data cstlink1;
    set cstlink1;
    if linkenddtnew = -50000 then delete;
    else if linkenddtnew ne . then linkenddt=linkenddtnew;
    drop linkenddtnew linkdtnew;
run;

%* UP TO THIS POINT I HAVE DONE NOTHING THAT THE FORTRAN CODE PROVIDED BY;
%* CRSP PRESUMABLY DOES -- CREATE A COMPOSITE RECORD FOR EACH GVKEY-PERMNO;
%* MATCH ENSURING THERE ARE NO OVERLAPPING MATCHES WITH OTHER GVKEYS;

%* --------------------------------------------------------------------------------;
%* Now apply slack;
%* Since cst/crsp is a many-to-many merge, need find the maximum amount of slack;
%* allowed going from CRSP--->Compustat and from Compustat---->CRSP;

proc sort data=cstlink1; by NPERMNO linkdt linkenddt; run;

data cstlink1;
    set cstlink1;
    npermnom1=lag(npermno);
    linkdtm1 =lag(linkdt);
    linkenddtm1 =lag(linkenddt);

    %* if there is no permno before;
    if npermno ne npermnom1 then max_preslack_permno = 90000;

    %* there is a permno before but the previous permno-gvkey link;
    %* is outside the slack range;
    else max_preslack_permno = intck('DAY',linkenddtm1,linkdt)-1;

run;

proc sort data=cstlink1; by NPERMNO descending linkdt descending linkenddt; run;

data cstlink1;
    set cstlink1;
    if npermno ne .;
    npermnop1=lag(npermno);
    linkdtp1 =lag(linkdt);
    linkenddtp1 =lag(linkenddt);

    if npermno ne npermnop1 then max_slack_permno = 90000;
    else max_slack_permno = intck('DAY',linkenddt,linkdtp1)-1;

    drop npermnom1 npermnop1 linkdtm1 linkdtp1 linkenddtm1 linkenddtp1;
run;

proc sort data=cstlink1;
    by gvkey linkdt;
run;

%* ----------------------------------------------------------------------;
%* Next, going the other direction;
%* This addresses point 3 in the introduction;
%* gvkey 1976 is a good debugger;

proc sort data=cstlink1; by gvkey linkdt; run;

data cstlink1;
    set cstlink1;
    npermnom1=lag(NPERMNO);
    gvkeym1  =lag(gvkey);
    linkenddtm1=lag(linkenddt);

    if gvkey ne gvkeym1 then max_preslack_gvkey = 90000;
    else max_preslack_gvkey = intck('DAY',linkenddtm1,linkdt)-1;
run;

proc sort data=cstlink1; by gvkey descending linkdt; run;

data cstlink1;
    set cstlink1;
    npermnop1=lag(NPERMNO);
    gvkeyp1  =lag(gvkey);
    linkdtp1 =lag(linkdt);

    if gvkey ne gvkeyp1 then max_slack_gvkey = 90000;
    else max_slack_gvkey = intck('DAY',linkenddt,linkdtp1)-1;

    drop npermnop: gvkeyp: linkdtp: npermnom: gvkeym: linkenddtm:
run;

*data mycstlink;
*    set cstlink1;
*    if linkenddt=today() then linkenddt=.;
*run;

%* finally, add new link date variables that include slack;
%* the s infront of linkdt and linkenddt is for "slack";

data mycstlink;
    format slinkdt date9. slinkenddt date9. extlinkdt date9. extlinkenddt date9.;
    set cstlink1;
    %* add slack to date range;
    slinkdt=intnx('DAY',linkdt,-min(abs(&preslack),max_preslack_permno,max_preslack_gvkey));
    slinkenddt=intnx('DAY',linkenddt,min(&slack,max_slack_permno,max_slack_gvkey));


    %* extreme range.  If it is the first permno and gvkey then set the;
    %* range to 1/1/1950 to .;
    extlinkdt = intnx('DAY',linkdt,-min(max_preslack_permno,max_preslack_gvkey));
    extlinkenddt=intnx('DAY',linkenddt,min(max_slack_permno,max_slack_gvkey));

    if slinkdt < mdy(1,1,1950) then slinkdt=mdy(1,1,1950);
    if slinkenddt > today() then slinkenddt = today();    
    if extlinkdt < mdy(1,1,1950) then extlinkdt=mdy(1,1,1950);
    if extlinkenddt > today() then extlinkenddt = today();    

    drop max_: linktype linkflag;
run;
    
proc sort data=mycstlink;
    by gvkey linkdt;
run;

%mend mycstlink;

/* MORE DISCUSSION

Possible combinations of overlapping date ranges

data are sorted by npermno, linkdt and then linkenddt

1) No adjustment necessary
|---------------------------|
                                   |------------------------|

2) Remove second range entirely
|-----------------------------------------------------------|
                |---------------------------------------|

	if linkdt > linkdtm1 and linkenddt < linkenddtm1 then do;
	   linkdtnew=0; linkenddtnew=0;
	end; 

3a) Adjust first range
|-----------------------------------------------------------|
                |-------------------------------------------|

adjusted as follows

|--------------|
                |-------------------------------------------|

        if linkdt < linkdtp1 and linkenddt = linkenddtp1 
	    then linkenddtnew = intnx('DAY',linkdtp1,-1);

3b) SIMILARLY adjust the first range

|---------------------------------------------------|
                |-------------------------------------------|

adjusted as follows

|--------------|
                |-------------------------------------------|

	if linkdt < linkdtp1 and linkenddt < linkenddtp1 and linkenddt > linkdtp1
	    then linkenddtnew=intnx('DAY',linkdtp1,-1);



4) Remove first range entirely
|-------------------------------------------|
|-----------------------------------------------------------|

        if linkdt = linkdtp1 and linkenddt < linkenddtp1 then do;
	    linkdtnew=0; linkenddtnew=0;
	end;


5) Remove both
|-----------------------------------------------------------|
|-----------------------------------------------------------|

        if linkdt=linkdtp1 and linkenddt=linkenddtp1 then do;
            linkdtnew=0; linkenddtnew=0;
        end;

        if linkdt=linkdtm1 and linkenddt=linkenddtm1 then do;
            linkdtnew=0; linkenddtnew=0;
        end;


The following code shows how many of each category there are:

data test5;
    set test4;
    format linkdtm1 date9. linkenddtm1 date9. linkdtp1 date9. linkenddtp1 date9.;
    if npermno ne npermnop1 then permnoaft=0;
    else do;
	if linkdt < linkdtp1 and linkenddt < linkenddtp1 and linkenddt > linkdtp1
	    then linkenddtnew=3.5;
	if linkdt = linkdtp1 and linkenddt < linkenddtp1 then do;
	    linkdtnew=4; linkenddtnew=4;
	end;
        if linkdt < linkdtp1 and linkenddt = linkenddtp1 
	    then linkenddtnew = 3;
        if linkdt=linkdtp1 and linkenddt=linkenddtp1 then do;
            linkdtnew=5; linkenddtnew=5;
        end;


    end;   

    if npermno ne npermnom1 then permnobef=0;
    else do;
	if linkdt > linkdtm1 and linkenddt < linkenddtm1 then do;
	   linkdtnew=2; linkenddtnew=2;
	end; 
        if linkdt=linkdtm1 and linkenddt=linkenddtm1 then do;
            linkdtnew=5.5; linkenddtnew=5.5;
        end;

    end;

run;

proc sql;
    select linkenddtnew, count(GVKEY) as num
    from test5
    group by linkenddtnew;
	   
linkenddtnew       num
----------------------
           .       451 (category 1)
           2         8
           3        12
         3.5        17
           4         8

Quoting from page 50 of ccm manual:

In cases where multiple gvkeys are simultaneously linked, a selection
criterion identifies the most appropriate one. The records (or data)
between gvkeys are not merged. Data for one gvkey per date range is mapped
to the PERMNO or PERMCO. The same process is used for either calendar or
fiscal year-based data, depending on the date associated with the wanted
data.After using the linktype field to screen out secondary links, the max
rule is used as the selection criterion.

Secondary linktypes excluded from the composite record in all cases are
LX, LD, LF, and LO. LS is excluded from PERMCO links if there is not also
a PERMNO link.

The max rule states that the gvkey with the more recent linkenddt is the
gvkey selected.

This means that when two companies have overlapping data, the one with the
most recent data is selected to represent the overlapping time period. For
example, PERMNO 10083 links to two gvkeys, 11947 and 15495, which have
overlapping calendar year-end data from January to December in
1988. crsp_cst_read_all will select only one gvkey for the overlapping
range in the composite record, as follows:

*/

