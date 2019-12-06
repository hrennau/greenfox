(:
 : -------------------------------------------------------------------------
 :
 : greenfoxEditUtil.xqm - Document me!
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
    "expressionEvaluator.xqm",
    "log.xqm" ;
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:harmonizePrefixes($doc as node(), 
                                     $namespace as xs:string, 
                                     $prefix as xs:string) as node() {
    f:harmonizePrefixesRC($doc, $namespace, $prefix)
};

declare function f:harmonizePrefixesRC($n as node(), 
                                       $namespace as xs:string, 
                                       $prefix as xs:string) as node()? {
    typeswitch($n)                                       
    case document-node() return document {$n/node() ! f:harmonizePrefixesRC(., $namespace, $prefix)}
    case element() return
        let $nname :=
            if ($n/not(namespace-uri(.) eq $namespace)) then () else
                QName($namespace, string-join(($prefix[string()], $n/local-name(.)), ':'))
        return
            element {$nname} {
                $n/@* ! f:harmonizePrefixesRC(., $namespace, $prefix),
                $n/node() ! f:harmonizePrefixesRC(., $namespace, $prefix)
            }
    case text() return
        if ($n/(../* and not(matches(., '\S')))) then () else $n
    default return $n
};
