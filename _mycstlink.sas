/*
**********************************************************************;
**********************************************************************;
Macro mycstlink
Created by Richard Price
Updated May 2009
**********************************************************************;
**********************************************************************;
Overview:

This macro creates a file that links GVKEY to PERMNO.  It uses as a
starting point the raw Compustat/CRSP merged files.  Code like this
was used to merge Compustat and CRSP in Beaver, McNichols and Price
(Journal of Accounting and Economics, 2007) which investigates a
number of causes of the inadvertent exclusion of delistings. Depending
on how Compustat and CRSP are merged, many delistings can be excluded
because the effective date range in the Compustat/CRSP merged database
often ends before the security is delisted.

You are entitled to a full refund if you find errors.  However, since
this code is free, that guarantee is pretty hollow.  I am fairly
confident in the output, but since every computer program has at least
one error, I don't exempt myself...  If you discover any errors,
please let me know.  Also, please cite the above paper if you do use
the code.

**********************************************************************;
Purpose:

This main purpose of this code is to extend the date range (linkdt,
linkenddt) where possible to ensure the maximum sample size.  Most of
the time, the date ranges provided by CRSP are fine, but there are
some instances where the date range ends before the security price
data ends.

The link between PERMNO and GVKEY is a many to many relationship. A
GVKEY may be related to different PERMNOs over its history.  Likewise
a PERMNO may be assigned to different GVKEYS.  Both of these issues
must be dealt with separately.

**********************************************************************;
Extending Link Date Ranges:

Of particular interest is allowing the beginning and ending effective
link dates to extend as far as posible, or as far as you want.  I
refer to this as slack.  Preslack is extending the linkdt to the
earliest possible date.  Slack is extending linkenddt to the latest
possible date.  Slack should not be allowed when conflicting GVKEY-PERMNO
matches exist.

In the old version of the CCM database, there were some instances of
overlapping GVKEY-PERMNO links (where a gvkey was linked to multiple
permnos or vice versa).  In the new database, CRSP has apparently
taken care of this problem (although I have found some instances of
overlapping date ranges, but CRSP periodically fixes these errors). In
this macro, I preserve the original date ranges from CRSP, and extend
them where appropriate.

**********************************************************************;
EXAMPLE 1:

As an example, consider GVKEY 5199 and 3998, which both link to permno
30278. 

Below are the valid date ranges from ccmxpf_lnkused
(usedflag=1).  There is an overlapping date range for six months,
which could result in some duplicate observations.  I do nothing to
correct this.  CRSP should fix this type of error eventually.

*** Date ranges from ccmxpf_lnkused;

UGVKEY   ULINKTYPE   UPERMNO   USEDFLAG    ULINKDT   ULINKENDDT

003998      LC        22860        1      19721214    19831229
003998      LC        30278        1      19831230    19850831
005199      LU        30278        1      19820406    19840629

** Date ranges produced by this macro;

  slinkdt slinkenddt extlinkdt extlinkenddt GVKEY  LPERMNO   LINKDT LINKENDDT

17JUN1972 29DEC1983  01JAN1925  29DEC1983   003998  22860  19721214 19831229 
30DEC1983 27FEB1986  30DEC1983  04MAY2009   003998  30278  19831230 19850831 
08OCT1981 29JUN1984  01JAN1925  29JUN1984   005199  30278  19820406 19840629 

Note that the linkdt and linkenddt variables are unchanged.  Two 
additional date ranges are added:

1) slinkdt, slinkenddt
2) extlinkdt, extlinkenddt

The first date range , slinkdt and slinkenddt, extend the date range
up to the number of days specified in the macro options (default
slack=180). The second date range, extlinkdt and extlinkenddt, extend
the date range as far as possible, i.e., if a gvkey links to no other
permnos, and the permno links to no other gvkeys, the extlinkdt is set
to 01JAN1925, and the extlinkenddt is set to today (04MAY2009).

With the first observation (gvkey 003998), it linkdt is fully extended
(slinkdt = 17JUN1972, extlinkdt=01JAN1925).  However, linkenddt is not
extended (linkenddt=slinkenddt=extlinkenddt) because there is another
link after the current link.

With the second observation (also gvkey 003998), linkenddt is fully
extended.  However, linkdt is not extended because GVKEY 003998 links
to permno 22860 prior to that.  Even if it did not, because GVKEY
005199 links to permno 30278, the linkdt would not be extended.

With the third observation (gvkey 005199), linkdt is extended as far
as possible because there is no conflicting prior link.  However,
linkenddt is not extended because the permno links to gvkey 003998
afterwards.

**********************************************************************;
EXAMPLE 2;

*** CCM date ranges for gvkey 001043;

GVKEY     LPERMNO       LINKDT    LINKENDDT    USEDFLAG

001043     18980      19581231    19620130         1
001043     18980      19620131    19820427         1  
** a gap here;
001043     18980      19840510    19930519         1  
** a gap here;
001043     80071      19931206    20000127         1

** this macro produces the following;

  slinkdt  slinkenddt  extlinkdt  extlinkenddt  GVKEY   LPERMNO    LINKDT  LINKENDDT

04JUL1958  30JAN1962   01JAN1925   30JAN1962    001043   18980   19581231  19620130 
31JAN1962  24OCT1982   31JAN1962   09MAY1984    001043   18980   19620131  19820427 
12NOV1983  15NOV1993   28APR1982   05DEC1993    001043   18980   19840510  19930519 
09JUN1993  25JUL2000   20MAY1993   04MAY2009    001043   80071   19931206  20000127 

**********************************************************************;
Identifiers in Compustat;

The primary identifier in Compustat is GVKEY.  In the new version of
Compustat, another identifier is added -- iid, the issue ID for a
security.  This will allow you to merge based on iid in addition.  I
think that there are additional issues that would need to be dealt
with with this type of merge, such as which iid do you use, and there
are apparently some cases where CRSP assigns an iid within CCM because
there is none assigned in Compustat (I have not verified this).  But
fundamentally, the GVKEY can have multiple security issues.

In most cases merges are done only by GVKEY.  I provide date ranges for
both types of merge.  First, for the merge done only on GVKEY, and second
for a merge done with GVKEY and iid.  I expect most people will only use
the merge based on GVKEY.

**********************************************************************;
Delistings after the linkenddt;

I have done some checking, and it still seems that the CCM date ranges
still need to be extended in some cases.  The following code shows
that there are many delistings after the linkenddt, although not as
many as before (it used to be about half of all delistings, it is now
about 5 percent, which is over 1,000 observations).

data delist;
    set crsp.mse;
    where dlstcd > 199;
    keep date permno dlstcd dlret dlpdt;
run;
** 21122 observations;

%mycstlink;
* run the macro to create the mycstlink dataset;

* merge gvkey with delisting file;
proc sql;
    create table delist2 as
        select distinct d.*, c.gvkey
        from delist d left join mycstlink c
        on d.permno=c.lpermno
	and c.linkdt le d.date le c.linkenddt;
** 21130 observations;
** there are some duplicates due to some overlapping date ranges in CRSP;
** I emailed CRSP with the list of problematic links;
** They will probably be fixed sometime;

* delistings that have no gvkey merged;
    select count(*) as n_unmerged
	from delist2
	where gvkey="";
** 5141 observations;

proc sql;
    create table ext_delist2 as
        select distinct d.*, c.gvkey
        from delist d left join mycstlink c
        on d.permno=c.lpermno
	and c.linkdt le d.date le c.extlinkenddt;
** 21130 observations -- my code doesn't cause any additional duplicates;

* delistings that have no gvkey merged after extending linkenddt;
    select count(*) as n_unmerged_extended
	from ext_delist2
	where gvkey="";
** 3995 observations;

The relevant comparison is the number of delistings that do not
merge. Using the CRSP-supplied range, there are 5,141 delistings that
do not merge vs 3,995 using extlinkenddt --- an additional 1,146
merged delistings.

**********************************************************************;
Input Variables:
  preslack: A variable indicating how many days before the linkdt to allow slack
     slack: A variable indicating how many days after the linkenddt to allow slack

          preslack and slack are numbers in DAYS that determines
          whether the variables linkbef or linkaft.  THE DEFAULT IS
          180 days for both.  Preslack can be positive or negative
          (absolute value functions are used to protect from potential
          errors).

          exclude_dual_class: some duplicates may exist because dual classes of
          shares exist.  To exclude them, set exclude_dual_class=1 (the default);
          Otherwise set to 0.

**********************************************************************;
Output: 
This macro creates a file in the working directory called
mycstlink. You can save this dataset somewhere.  But since the macro
runs quickly, there is no need.

  VARIABLES CREATED:
  
  FOR A MERGE BASED ONLY ON GVKEY (NOT IID)
          slinkdt: This is a link date that incorporates preslack (equals linkdt - preslack)
       slinkenddt: This is a link end date that incorporates slack (postslack)
                   This equals linkenddt + slack.
        extlinkdt: This equals 1/1/1925 or the earliest possible date
     extlinkenddt: This equals the latest possible date, with the maximum date being today
                   (the date you run the program).

  FOR A MERGE BASED ON GVKEY AND IID
          slinkdt_iid  (same descriptions as above)
       slinkenddt_iid
        extlinkdt_iid
     extlinkenddt_iid

  Note:
        linkenddt: Note that I set linkenddt to today's date rather than .E.  It makes
                   it easier to work with.

**********************************************************************;
NOTE:  The use of extlink and slink variables may result in some
       overlapping ranges because with extlinkdt and extlinkenddt the
       range expands as far as possible until arriving at another
       active link.  However that active link ext dates also expand as
       far as possible.
       
       For example, for a hypothetical GVKEY:
            linkdt     linkenddt    NPERMNO   extlinkdt  extlinkenddt
            19720101   19761030         X     19250101   19761231
            19770101   19770330         Y     19761031   20090504

       The first observation has extlinkenddt to 19761231.  The second
       observation has extlinkdt as 19761031.  If there was any security
       price data between 19761031 and 19761231, it would merge with both
       GVKEYs if extlinkdt and extlinkenddt are used.

       This can be addressed in two ways.  First, allow slack (after)
       but no preslack (before). This would extend the effective end
       date as far as possible, but leaves the effective beginning
       date alone. Second, the variables in the macro which determine
       the amount of allowable slack (max_slack_gvkey,
       max_slack_permno, max_preslack_gvkey, max_preslack_permno)
       could be adjusted in some way.  However, I do not do this, and
       in general think the first method is fine.

       In general, I think it is more important to ensure that the end
       date range is extended rather than the beginning date
       range.  As documented in Beaver, McNichols and Price (2007)
       nearly half of all delistings occured outside the stated range
       in the CCM database.  (I think this problem is less severe, but
       up to 10% of delistings occur after the end of the date
       range).  I have not investigated whether beginning date ranges
       need to be extended.

       You should pay attention to your datasets to make sure that the
       number of observations is not changing in unexpected ways.  A
       good way to keep duplicate observations out in sas is to use
       the "select distinct" option with proc sql.  However, this may
       not always eliminate duplicate observations.  I have found that
       the most effective methods of debugging are 1) looking at the
       data to make sure your code is working correctly and 2) reading
       the log file and paying close attention to the number of
       observations.

**********************************************************************;
       See the _mycstlink_example.sas for an illustration of how to
       use this macro.
**********************************************************************;
**********************************************************************;
*/ 

%macro mycstlink(preslack=180,slack=180,exclude_dual_class=1);

%* in case slack is ever set to null;
%if &preslack= %then %let preslack=0;
%if &slack= %then %let slack=0;

%* this is the same as ccmxpf_linktable;
proc sql;
    create table cstlink0 as
	select h.*, u.usedflag
	from crsp.ccmxpf_lnkhist h left join crsp.ccmxpf_lnkused u
	on (h.gvkey=u.ugvkey) 
	and (h.lpermno=u.upermno) 
	and (h.lpermco=u.upermco) 
	and (h.linkdt=u.ulinkdt) 
	and (h.linkenddt=u.ulinkenddt)
	and (h.liid=u.uiid);

data cstlink1;
    set cstlink0;
    if usedflag=1;
    if linkenddt=.E then linkenddt=today();
    gvkey_liid = gvkey || liid;
run;
%* In the new Compustat database, the variable iid is used;
%* to match gvkeys to securities.  So the CCM database adds;
%* iid in the gvkey-permno match.  I create the variable gvkey_iid;
%* by concatenating gvkey and iid and use it instead of gvkey;

%* --------------------------------------------------------------------------------;
%* Apply slack;
%* Since cst/crsp is a many-to-many merge, need find the maximum amount of slack;
%* allowed going from CRSP--->Compustat and from Compustat---->CRSP;

proc sort data=cstlink1; 
    by LPERMNO linkdt linkenddt; 
run;

data cstlink1;
    set cstlink1;
    lpermnom1=lag(lpermno);
    linkdtm1 =lag(linkdt);
    linkenddtm1 =lag(linkenddt);

    %* if there is no permno before;
    if lpermno ne lpermnom1 then max_preslack_permno = 90000;

    %* there is a permno before but the previous permno-gvkey link;
    %* is outside the slack range;
    else max_preslack_permno = intck('DAY',linkenddtm1,linkdt)-1;
    %* this is complicated by the fact that multiple gvkey_iids can link to the same permno;
run;

proc sort data=cstlink1; 
    by LPERMNO descending linkdt descending linkenddt; 
run;

data cstlink1;
    set cstlink1;
    if lpermno ne .;
    lpermnop1=lag(lpermno);
    linkdtp1 =lag(linkdt);
    linkenddtp1 =lag(linkenddt);

    if lpermno ne lpermnop1 then max_slack_permno = 90000;
    else max_slack_permno = intck('DAY',linkenddt,linkdtp1)-1;

    drop lpermnom1 lpermnop1 linkdtm1 linkdtp1 linkenddtm1 linkenddtp1;
run;


%*** now sort by linkenddt.  This is precautionary, and should only apply;
%*** if there are overlapping ranges.  It may not be necessary;
proc sort data=cstlink1; 
    by LPERMNO linkenddt linkdt; 
run;

data cstlink1;
    set cstlink1;
    lpermnom1=lag(lpermno);
    linkdtm1 =lag(linkdt);
    linkenddtm1 =lag(linkenddt);

    %* if there is no permno before;
    if lpermno ne lpermnom1 then max_preslack_permno_2 = 90000;

    %* there is a permno before but the previous permno-gvkey link;
    %* is outside the slack range;
    else max_preslack_permno_2 = intck('DAY',linkenddtm1,linkdt)-1;
run;

proc sort data=cstlink1; 
    by LPERMNO descending linkenddt descending linkdt;
run;

data cstlink1;
    set cstlink1;
    if lpermno ne .;
    lpermnop1=lag(lpermno);
    linkdtp1 =lag(linkdt);
    linkenddtp1 =lag(linkenddt);

    if lpermno ne lpermnop1 then max_slack_permno_2 = 90000;
    else max_slack_permno_2 = intck('DAY',linkenddt,linkdtp1)-1;

    drop lpermnom1 lpermnop1 linkdtm1 linkdtp1 linkenddtm1 linkenddtp1;
run;

%* ----------------------------------------------------------------------;
%* Next, sorting by gvkey_liid;

proc sort data=cstlink1; 
    by gvkey_liid linkdt linkenddt; 
run;

data cstlink1;
    set cstlink1;
    lpermnom1=lag(LPERMNO);
    gvkey_liidm1  =lag(gvkey_liid);
    linkenddtm1=lag(linkenddt);

    if gvkey_liid ne gvkey_liidm1 then max_preslack_gvkey_liid = 90000;
    else max_preslack_gvkey_liid = intck('DAY',linkenddtm1,linkdt)-1;
run;

proc sort data=cstlink1; 
    by gvkey_liid descending linkdt descending linkenddt; 
run;

data cstlink1;
    set cstlink1;
    lpermnop1=lag(LPERMNO);
    gvkey_liidp1  =lag(gvkey_liid);
    linkdtp1 =lag(linkdt);

    if gvkey_liid ne gvkey_liidp1 then max_slack_gvkey_liid = 90000;
    else max_slack_gvkey_liid = intck('DAY',linkenddt,linkdtp1)-1;

    drop lpermnop: gvkey_liidp: linkdtp: lpermnom: gvkey_liidm: linkenddtm:;
run;

%* ----------------------------------------------------------------------;
%* Next, sorting by gvkey only;

proc sort data=cstlink1; 
    by gvkey linkdt linkenddt;
run;

data cstlink1;
    set cstlink1;
    lpermnom1=lag(LPERMNO);
    gvkeym1  =lag(gvkey);
    linkenddtm1=lag(linkenddt);

    if gvkey ne gvkeym1 then max_preslack_gvkey = 90000;
    else max_preslack_gvkey = intck('DAY',linkenddtm1,linkdt)-1;
run;

proc sort data=cstlink1; 
    by gvkey descending linkdt descending linkenddt; 
run;

data cstlink1;
    set cstlink1;
    lpermnop1=lag(LPERMNO);
    gvkeyp1  =lag(gvkey);
    linkdtp1 =lag(linkdt);

    if gvkey ne gvkeyp1 then max_slack_gvkey = 90000;
    else max_slack_gvkey = intck('DAY',linkenddt,linkdtp1)-1;

    drop lpermnop: gvkeyp: linkdtp: lpermnom: gvkeym: linkenddtm:;
run;


%* ----------------------------------------------------------------------;
%* Finally, add new link date variables;

data mycstlink;
    format slinkdt_iid slinkenddt_iid extlinkdt_iid extlinkenddt_iid slinkdt slinkenddt extlinkdt extlinkenddt date9.;
    set cstlink1;

    %* slack for sort by gvkey_liid;
    preslack = max(0,min(max_preslack_permno,max_preslack_permno_2,max_preslack_gvkey_liid));
    slack = max(0,min(max_slack_permno,max_slack_permno_2,max_slack_gvkey_liid));
    %* there may be cases where max_slack and max_preslack are negative;
    %* They are likely cases where there are overlapping (incorrect) date ranges;
    %* in CRSP.  In these cases, I leave the date ranges alone;
    
    %* add slack to date range;
    slinkdt_iid=intnx('DAY',linkdt,-min(abs(&preslack),preslack));
    slinkenddt_iid=intnx('DAY',linkenddt,min(&slack,slack));

    %* extreme range.  If it is the first permno and gvkey_liid then set the;
    %* range to 1/1/1925 to today;
    extlinkdt_iid = intnx('DAY',linkdt,-preslack);
    extlinkenddt_iid=intnx('DAY',linkenddt,slack);

    if slinkdt_iid < mdy(1,1,1925) then slinkdt_iid=mdy(1,1,1925);
    if slinkenddt_iid > today() then slinkenddt_iid = today();    
    if extlinkdt_iid < mdy(1,1,1925) then extlinkdt_iid=mdy(1,1,1925);
    if extlinkenddt_iid > today() then extlinkenddt_iid = today();    

    %* slack for sort by gvkey;
    preslack2 = max(0,min(max_preslack_permno,max_preslack_permno_2,max_preslack_gvkey));
    slack2 = max(0,min(max_slack_permno,max_slack_permno_2,max_slack_gvkey));
    %* there may be cases where max_slack and max_preslack are negative;
    %* They are likely cases where there are overlapping (incorrect) date ranges;
    %* in CRSP.  In these cases, I leave the date ranges alone;
    
    %* add slack to date range;
    slinkdt=intnx('DAY',linkdt,-min(abs(&preslack),preslack2));
    slinkenddt=intnx('DAY',linkenddt,min(&slack,slack2));
    extlinkdt = intnx('DAY',linkdt,-preslack2);
    extlinkenddt=intnx('DAY',linkenddt,slack2);

    if slinkdt < mdy(1,1,1925) then slinkdt=mdy(1,1,1925);
    if slinkenddt > today() then slinkenddt = today();    
    if extlinkdt < mdy(1,1,1925) then extlinkdt=mdy(1,1,1925);
    if extlinkenddt > today() then extlinkenddt = today();    

    if &exclude_dual_class=1 then do;
        if linkprim in ("J" "N") then delete;
        end;

    drop max_: gvkey_liid usedflag slack: preslack:;
run;
    
proc sort data=mycstlink;
    by gvkey liid linkdt;
run;

%mend mycstlink;
