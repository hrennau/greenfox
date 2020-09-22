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
declare function f:validateConditionalConstraint($constraintElem as element(gx:conditional), 
                                                 $context as map(*))
        as element()* {
    
    let $if := $constraintElem/gx:if[1]
    let $then := $constraintElem/gx:then[1]
    let $elseif := $constraintElem/gx:elseIf
    let $else := $constraintElem/gx:else
    
    let $ifResults := ()
};
