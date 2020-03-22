(:
 : -------------------------------------------------------------------------
 :
 : validate.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm",
    "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" at
    "compile.xqm",
    "constants.xqm",
    "greenFoxValidator.xqm",
    "systemValidator.xqm";
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:DEBUG($items as item()*,
                         $debugTag as xs:string,
                         $debugLevel as xs:integer,
                         $label as xs:string) 
        as item()* {
    if ($debugLevel gt $i:DEBUG_LEVEL or not($debugTag = $i:DEBUG_TAGS)) then ()
    else trace($items, $label)
};

declare function f:DEBUG_FILE($item as item(),
                              $debugLevel as xs:integer,
                              $fileName as xs:string) {
    if ($debugLevel gt $i:DEBUG_LEVEL) then () else
    file:write($i:DEBUG_FOLDER || '/' || $fileName, $item)
};
