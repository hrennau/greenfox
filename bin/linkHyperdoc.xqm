(:
 : -------------------------------------------------------------------------
 :
 : linkHyperdoc.xqm - maps a resource and a link definition to a hyperdoc
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions/greenlink";

import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" 
at "linkUtil.xqm";

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "expressionEvaluator.xqm",
   "greenfoxUtil.xqm",
   "log.xqm",
   "uriUtil0.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

declare function f:getLinkHyperdoc($linkUsingElem as element(), 
                                   $context as map(xs:string, item()*))
        as map(xs:string, item()*) {
     
    let $targetInfo := $context?_targetInfo
    let $contextURI := $targetInfo?contextURI
    let $useContextNode := ($targetInfo?focusNode, $targetInfo?doc)[1]
        
    let $ldo := link:getLinkDefObject($linkUsingElem, $context)
    let $lros := 
        let $options := map{'mediatype': 'xml'}
        return
            link:resolveLinkDef($ldo, 'lro', $contextURI, $useContextNode, $context, $options) 
            [not(?targetURI ! i:fox-resource-is-dir(.))]   (: ignore folders :)
            
    let $lrosError := $lros[?errorCode]
    let $lrosOk := $lros[not(?errorCode)]
    (:let $_DEBUG := trace( i:DEBUG_LROS($lros) , '___LROS: ') :)
    
    (: Check link constraints :)
    let $linkValidationResults := link:validateLinkConstraints($lros, $ldo, $linkUsingElem, $context) 

    let $docs := $lros?targetDoc
    let $hyperdoc :=
        document {
            <hyperdoc xml:base="{$contextURI}">{
                for $lro in $lros[not(?errorCode)]
                let $targetDoc := $lro?targetDoc/*
                where $targetDoc
                return
                    element {node-name($targetDoc)} {
                        attribute xml:base {$lro?targetURI},
                        $targetDoc/@*,
                        $targetDoc/node()
                    }
            }</hyperdoc>
        }
    let $results := map{
        'linkValidationResults': $linkValidationResults, 
        'hyperdoc': $hyperdoc,
        'lrosError': $lrosError
    }
        
    return $results
};
