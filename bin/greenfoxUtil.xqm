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
declare function f:validateTargetCount($constraint as element(), $targetCount as xs:integer)
        as element()* {
    let $constraintParams := $constraint/(@count, @minCount, @maxCount)  
    
    let $count := $constraint/@count/xs:integer(.)
    let $minCount := $constraint/@minCount/xs:integer(.)
    let $maxCount := $constraint/@maxCount/xs:integer(.)
    let $error := (
        exists($count) and $count ne $targetCount
        or
        exists($minCount) and $minCount gt $targetCount
        or 
        exists($maxCount) and $maxCount lt $targetCount
    )
    where $error    
    return
        let $msg := $constraint/@msg
        return
            <gx:error constraintComp="targetCount">{ 
                $constraint/@id/attribute constraintID {.},
                $constraintParams,
                attribute actCount {$targetCount},
                $msg
            }</gx:error>
(:    
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
            <gx:error constraintComp="targetCount">{ 
                      $constraint/@id/attribute constraintID {.},
                      $params,
                      attribute actCount {$targetCount},
                      $msg
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
:)    
};

(:~
 : Creates an augmented copy of an error element, adding specified attributes.
 :
 : @param error an error element
 : @param atts attributes to be added
 : @return augmented error element
 :)
declare function f:augmentErrorElement($error as element(gx:error), $atts as attribute()+, $position as xs:string?)
        as element(gx:error) {
    let $addedAttNames := $atts/node-name(.)        
    let $curAtts := $error/@*[not(node-name(.) = $addedAttNames)]
    return
        element {node-name($error)} {
            if ($position eq 'first') then ($atts, $curAtts) else ($curAtts, $atts),
            $error/node()
        }};        


