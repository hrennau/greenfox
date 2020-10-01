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
 : Return a concise description of LROs.
 :)
declare function f:DEBUG_LROS($lros as map(*)*) 
        as element()? {
    let $entries :=
        for $lro in $lros
        let $keys := map:keys($lro) => sort()
        return
            <lro>{
                for $key in $keys
                let $items :=
                    for $item in $lro($key)
                    return
                        typeswitch($item)
                        case element() return attribute itemType {'element(' || $item/name() || ')'}
                        case attribute() return attribute itemType {'attribute(' || $item/name() || ')=' || $item}
                        case document-node() return 
                            attribute itemType {'document-node(' || $item/*/name() || ')'}
                        default return $item
                where not($key eq 'type' and $items = 'linkResolutionObject')
                return element {$key} {$items}
            }</lro>
    return
        <lros count="{count($entries)}">{$entries}</lros>
};        

