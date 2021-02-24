(:
 : -------------------------------------------------------------------------
 :
 : log.xqm - functions for debuging
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_request.xqm",
   "tt/_reportAssistent.xqm",
   "tt/_errorAssistent.xqm",
   "tt/_log.xqm",
   "tt/_nameFilter.xqm",
   "tt/_pcollection.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "compile.xqm",
   "constants.xqm",
   "greenfoxSchemaValidator.xqm",
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

declare function f:DEBUG_CONTEXT($label as xs:string,
                                 $debugLevel as xs:integer,
                                 $context as map(xs:string, item()*))
        as empty-sequence() {
    if ($debugLevel ge $i:DEBUG_LEVEL) then () else        
    let $dir := $i:DEBUG_FOLDER
    let $fname := $dir || '/DEBUG.CONTEXT_' || $label || '.xml'
    let $contextDoc :=
        <context>{
            f:DEBUG_CONTEXT_RC($context)
        }</context>
    return
        file:write($fname, $contextDoc)
};

declare function f:DEBUG_CONTEXT_RC($item as item()) as item()* {
    typeswitch($item)
    case map(*) return
        for $key in map:keys($item) 
        let $value := $item($key)
        order by string($key)
        return
            element {$key} {
                if (count($value) eq 1) then f:DEBUG_CONTEXT_RC($value)
                else $value ! <_item>{f:DEBUG_CONTEXT_RC(.)}</_item>
            }
            
    case attribute() return
        <attribute name="{$item/name()}" value="{$item}"/>
    case element() return
        <element name="{$item/name()}"/>
    case document-node() return
        <document rootName="{$item/*/name()}"/>
        
    default return $item            
};

(:~
 : Return an XML representation of a Link Definition Object. Intended for use
 : when writing an LDO into a file.
 :
 : @param ldo a Link Definition Object
 : @return an <ldo> element representing the LDO
 :)
declare function f:DEBUG_LDO($ldo as map(*)) 
        as element()? {
    let $keys := map:keys($ldo)[not(. eq 'constraints')] => sort()
    return
       <ldo>{
        for $key in $keys
        let $value := $ldo($key)
        return 
            typeswitch($value)
            case(map(*)) return f:DEBUG_map2elem($value, $key)
            case attribute() return element {$key} {string($value)}
            default return element {$key} {$value},
        $ldo?constraints ! . 
       }</ldo>
};

(:~
 : Transforms a map into an element.
 :
 : @param map a map
 : @param name the element name to be used
 : @return an element representing the map
 :)
declare function f:DEBUG_map2elem($map as map(*), $name as xs:string)
        as element() {
    let $content :=        
        let $keys := map:keys($map)
        for $key in $keys 
        let $value := $map($key)
        order by lower-case($key)
        return
            typeswitch($value)
            case map(*) return f:DEBUG_map2elem($value, $key)
            case attribute() return element {$key} {string($value)}
            default return element {$key} {$value}
    return
        element {$name} {$content}
};        

(:~
 : Return a concise description of LROs.
 :
 : Returns an <lros> element with <lro> children,
 : each one describing an LRO object.
 :
 : @param lros a sequence of LRO objects
 : @return a document describing the LRO objects
 :)
declare function f:DEBUG_LROS($lros as map(*)*) 
        as element()? {
        
    let $fn_getItemType := function($node) {
        typeswitch($node)
        case element() return 'element(' || $node/name() || ')'
        case attribute() return 'attribute(' || $node/name() || ')=' || $node
        case document-node() return 'document-node(' || $node/*/name() || ')'
        case text() return 'text()=' || $node
        default return 'node()=' || $node
    }
    
    let $entries :=
        for $lro in $lros
        let $keys := map:keys($lro) => sort()
        return
            <lro>{
                for $key in $keys
                let $items :=
                    let $rawItems := $lro($key)
                    let $nodes := $rawItems[. instance of node()]
                    let $atoms := $rawItems[. instance of xs:anyAtomicType]                    
                    return ( 
                        if (empty($nodes)) then ()
                        else if (count($nodes) eq 1) then $fn_getItemType($nodes)
                        else $nodes/<node itemType="{$fn_getItemType(.)}"/>
                        ,
                        $atoms
                    )
                where not($key eq 'type' and $items = 'linkResolutionObject')
                return element {$key} {$items}
            }</lro>
    return
        <lros count="{count($entries)}">{$entries}</lros>
};      

(:~
 : Returns the input value and optionally also writes it to a file. Writing is suppressed
 : if the $debugLevel is 0, or if a $debugLabel is supplied which does not match any of
 : the $debugFilters. A debug label can be used in order to accomplish selective debugging,
 : for example restricted to processing elements with a particular name.
 :
 : @param value the value to be written
 : @param msg a message to be written 
 : @param debugLevel the current debug level; if 0, nothing is written
 : @param debugLabel if set, nothing is written unless the label matches at least one filter
 : @param debugFilters output is suppressed unless debugLabel matches one of the filters
 : @param fileName the output file
 : @return the value
 :)
declare function f:FDEBUG($value as item()*, 
                          $msg as xs:string,
                          $debugLevel as xs:integer,
                          $debugLabel as xs:string,
                          $debugFilters as xs:string*,                          
                          $fileName as xs:string)
        as item()* {
    $value,
    
    if (not($debugLevel)) then $value        
    else if ($debugLabel and 
             not(some $debugFilter in $debugFilters satisfies 
                matches($debugLabel, $debugFilter, 'i'))) then $value
    else (
        (: Return the input value :)
        $value,
        
        (: Append to file :)
        file:append($fileName, '### ' || $msg || '&#xA;'),
        file:append($fileName, $value),
        file:append($fileName, '&#xA;&#xA;')
    )
};


