(:~
 : -------------------------------------------------------------------------
 :
 : conditionalConstraint.xqm - functions checking a conditional constraint
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "greenfoxUtil.xqm";

import module namespace result="http://www.greenfox.org/ns/xquery-functions/validation-result" 
at "validationResult.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Validates a conditional constraint.
 :
 : @param constraintElem an element declaring the condition of a conditional constraint
 : @param context the processing context
 : @return validation results
 :)
declare function f:validateConditionalConstraint(
                    $constraintElem as element(gx:conditional), 
                    $validator as function(element(), map(xs:string, item()*)) as element()*,
                    $context as map(*))
        as element()* {
    
    let $if := $constraintElem/gx:if[1]
    let $then := $constraintElem/gx:then[1]
    let $elseif := $constraintElem/gx:elseIf
    let $else := $constraintElem/gx:else[1]
    
    let $ifResults := $if/$validator(., $context)
    let $ifTrue := every $result in $ifResults satisfies $result/self::gx:green
    return (
        $ifResults/f:whitenResults(.),
        if ($ifTrue) then $then/$validator(., $context)        
        else $else/$validator(., $context)
    )        
};

(:~
 : Transforms results so that 'red', 'yellow' and 'green' is
 : marked as not describing validity, as they have been produced in
 : order to determine a condition.
 :)
declare function f:whitenResults($results as element()*)
        as element()* {
    for $result in $results
    return
        typeswitch($result)
        case element(gx:red) return element gx:whiteRed {$result/(@*, node())}
        case element(gx:green) return element gx:whiteGreen {$result/(@*, node())}
        case element(gx:yellow) return element gx:whiteYellow {$result/(@*, node())}
        default return $result
};        
