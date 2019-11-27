(:
 : -------------------------------------------------------------------------
 :
 : greenfoxUtil.xqm - Document me!
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
    "log.xqm" ;
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates the target count of a resource shape.
 :
 : @param shape a resource shape
 : @targetCount the number of instances belonging to the target of the shape
 : @return elements signaling violations of the count constraints
 :) 
declare function f:validateTargetCount($shape as element(), $targetCount as xs:integer)
        as element()* {
    let $class := 
        let $lname := $shape/local-name(.)
        return concat($lname, if (contains($lname, 'Subset')) then 'Size' else 'SetSize')     
    let $idAttName := concat($shape/local-name(.), 'ID')
    let $labelAttName := concat($shape/local-name(.), 'Label')
    
    let $identAtt :=
        $shape/(@subsetLabel, @resourceSetLabel)
    let $count := $shape/@count/xs:integer(.)
    let $minCount := $shape/@minCount/xs:integer(.)
    let $maxCount := $shape/@maxCount/xs:integer(.)
    let $countErrors := (
        if (empty($count) or $targetCount eq $count) then () else            
            <gx:error class="{$class}">{ 
                      $shape/@id/attribute {$idAttName} {.},
                      $identAtt/attribute {$labelAttName} {.},
                      attribute code {'unexpected-target-count'},
                      attribute expectedCount {$count},
                      attribute actualCount {$targetCount}
            }</gx:error>,
        if (empty($minCount) or $targetCount ge $minCount) then () else            
            <gx:error class="{$class}">{
                      $shape/@id/attribute {$idAttName} {.},
                      $identAtt/attribute {$labelAttName} {.},            
                      attribute code {'too-small-target-count'},
                      attribute expectedMinCount {$minCount},
                      attribute actualCount {$targetCount}
            }</gx:error>,
        if (empty($maxCount) or $targetCount le $maxCount) then () else            
            <gx:error class="{$class}">{
                      $shape/@id/attribute {$idAttName} {.},
                      $identAtt/attribute {$labelAttName} {.},            
                      attribute code {'too-large-target-count'},
                      attribute expectedMaxCount {$maxCount},
                      attribute actualCount {$targetCount}
            }</gx:error>
    )
    return $countErrors
};


