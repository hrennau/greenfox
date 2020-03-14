(:
 : -------------------------------------------------------------------------
 :
 : validationReportMerger.xqm - functions merging validation reports
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxUtil.xqm",
    "resourceAccess.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";
