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
 : Validates instance count constraints applying to a resource set.
 :
 : @param shape the shape constraining the resource set
 : @instanceCount the number of instances belonging to the shape target
 : @return elements signaling violations of the count constraints
 :) 
declare function f:validateInstanceCount($shape as element(), $instanceCount as xs:integer)
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
        if (empty($count) or $instanceCount eq $count) then () else            
            <gx:error class="{$class}">{ 
                      $shape/@id/attribute {$idAttName} {.},
                      $identAtt/attribute {$labelAttName} {.},
                      attribute code {'unexpected-instance-count'},
                      attribute expectedCount {$count},
                      attribute actualCount {$instanceCount}
            }</gx:error>,
        if (empty($minCount) or $instanceCount ge $minCount) then () else            
            <gx:error class="{$class}">{
                      $shape/@id/attribute {$idAttName} {.},
                      $identAtt/attribute {$labelAttName} {.},            
                      attribute code {'too-small-instance-count'},
                      attribute expectedMinCount {$minCount},
                      attribute actualCount {$instanceCount}
            }</gx:error>,
        if (empty($maxCount) or $instanceCount le $maxCount) then () else            
            <gx:error class="{$class}">{
                      $shape/@id/attribute {$idAttName} {.},
                      $identAtt/attribute {$labelAttName} {.},            
                      attribute code {'too-large-instance-count'},
                      attribute expectedMaxCount {$maxCount},
                      attribute actualCount {$instanceCount}
            }</gx:error>
    )
    return $countErrors
};
