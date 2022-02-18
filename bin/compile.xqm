(:
 : -------------------------------------------------------------------------
 :
 : compile.xqm - functions compiling a greenfox schema, producing an augmented copy.
 :
 : Changes:
 : - finalization of the processing context (<context>)
 : - variable substitution (using the `context` element)
 : - add @xml:base to the root element
 : - add id attributes: @id, @valueShapeID, @resourceShapeID :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at 
    "tt/_request.xqm",
    "tt/_reportAssistent.xqm",
    "tt/_errorAssistent.xqm",
    "tt/_log.xqm",
    "tt/_nameFilter.xqm";    
    
import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at
    "constants.xqm",
    "greenfoxUtil.xqm",
    "greenfoxVarUtil.xqm",
    "processingContext.xqm";
    
import module namespace link="http://www.greenfox.org/ns/xquery-functions/greenlink" at
    "linkDefinition.xqm";
    
declare namespace gx="http://www.greenfox.org/ns/schema";

(: ============================================================================
 :
 :     f u n c t i o n    c o m p i l i n g    t h e    s c h e m a
 :
 : ============================================================================ :)

(:~
 : Compiles a greenfox schema and returns an augmented copy of the schema, plus
 : a context map. The context map consists of the context map contained by the
 : schema, extended/overwritten by the name-value pairs supplied as
 : external context. 
 :
 : The following documentation is currently not valid:
 :   In the augmented schema, components with a component
 :   reference are replaced with the referenced component, augmented with the
 :   attributes and content elements of the referencing component.
 :
 : @param gfox a greenfox schema
 : @param params a string encoding parameter value assignments supplied by the user
 : @param domain the path of the domain, as supplied by the user
 : @return the augmented schema, and a context map
 :)
declare function f:compileGreenfox($gfox as element(gx:greenfox), 
                                   $params as xs:string?,
                                   $domain as xs:string?) 
        as map(xs:string, item()*) {
    (: Construct the initial context :)
    let $context := f:initialProcessingContext($gfox, $params, $domain)
    
    (: Perform variable substitution :)
    let $gfox2 := f:substituteVariablesRC($gfox, $context)
    let $gfox3 := f:compileGreenfox_addIds($gfox2)
    let $gfox4 := f:compileGreenfox_addResourceShapeIds($gfox3)    
    let $context2 := f:updateProcessingContext_resourceRelationships($context, $gfox4/gx:linkDef)
    return
        map{'schemaPrelim': $gfox2, 
            'schemaCompiled': $gfox4, 
            'context': $context2}
};

(: ============================================================================
 :
 :     f u n c t i o n s    s u b s t i t u t i n g    v a r i a b l e    r e f e r e n c e s
 :
 : ============================================================================ :)
 
 (:~
 : Returns an augmented copy of a greenfox schema. Changes:
 : (a) @xml:base added to the root element
 : (b) text nodes and attributes: variable substitution
 :
 : @param n a node of the greenfox schema currently processed.
 : @param context a set of external variables
 : @return the processing result
 :)
declare function f:substituteVariablesRC($n as node(), $context as map(xs:string, item()*)) as node() {
    typeswitch($n)
    case document-node() return document {$n/node() ! f:substituteVariablesRC(., $context)}
    
    (: Copies the root element, adds an @xml:base if not yet present :)
    case element(gx:greenfox) return
        element {node-name($n)} {
            i:copyNamespaceNodes($n),
            $n/@* ! f:substituteVariablesRC(., $context),
            if ($n/@xml:base) then () else attribute xml:base {base-uri($n)},
            $n/node() ! f:substituteVariablesRC(., $context) 
        }

    (: Context - add entries from external context not contained by schema context :)
    case element(gx:context) return
        element {node-name($n)} {
            map:keys($context)[not(. = $n/gx:field/@name)] 
            ! <field xmlns="http://www.greenfox.org/ns/schema" name="{.}" value="{$context(.)}"/>,
            $n/* ! f:substituteVariablesRC(., $context)
        }
        
    case element(gx:field) return
        let $name := $n/@name
        return
            element {node-name($n)} {
                $n/@name ! f:substituteVariablesRC(., $context),
                $n/attribute value {($context($name), @value)[1]}
            }
        
    (: Copies the element :)
    case element() return
        element {node-name($n)} {
            i:copyNamespaceNodes($n),
            $n/@* ! f:substituteVariablesRC(., $context),
            $n/node() ! f:substituteVariablesRC(., $context)            
        }
        
    (: text node - variable substitution :)
    case text() return text {string($n) ! f:substituteVars(., $context, ())}
    
    (: attribute - variable substitution :)
    case attribute() return 
    attribute {node-name($n)} {string($n) ! f:substituteVars(., $context, ())}
    
    default return $n        
};

(: ============================================================================
 :
 :     f u n c t i o n s    a d d i n g    I D    a t t r i b u t e s
 :
 : ============================================================================ :)

(:~
 : Adds @id and further attributes to selected elements. Added attributes:
 : @id, @resourceShapeID, @valueShapeID.
 :
 : Special rules:
 : - @resourceShapeID is added to `file` and `folder` elements only
 : - @valueShapeID is added to `xpath`, `foxpath` and `links` elements only
 : - on `mediatype`elements, the ID attribute is called `constraintID`, 
 :   rather than `id`.
 :
 : Selected elements: all elements except for `context` and its descendants.
 :
 : @param gfox a greenfox schema
 : @return an augmented copy, containing the added attributes
 :)
declare function f:compileGreenfox_addIds($gfox as element(gx:greenfox)) {
    copy $gfox_ := $gfox
    modify
        let $elems := ($gfox_//*) except ($gfox_/gx:context/descendant-or-self::*)
        for $elem in $elems
        group by $localName := local-name($elem)
        return
            for $e at $pos in $elem
            
            (: Add @id attribute :)
            let $idAtt := $e/@id
            let $idValue := ($idAtt, concat($localName, '_', $pos))[1]
            let $idName :=
                switch($localName)
                case 'mediatype' return 'constraintID'
                default return 'id'
                
            (: Add further attributes, if applicable (@resourceShapeID, @valueShapeID) :)
            let $furtherAtts:=
                typeswitch($elem[1])
                case element(gx:file) | element(gx:folder) return (
                    attribute resourceShapePath {f:getSchemaPath($elem[1], ())},
                    if ($elem/@resourceShapeID) then ()
                    else attribute resourceShapeID {$idValue}
                )
                case element(gx:xpath) | element(gx:foxpath) | element(gx:links) return
                    if ($elem/@valueShapeID) then ()
                    else attribute valueShapeID {$idValue}
                default return ()
            return
            (: Delete existing @id, add @id and further attributes :)
            (
                $idAtt/(delete node .),
                insert node (attribute {$idName} {$idValue}, $furtherAtts) as first into $e                
            )                
    return $gfox_                
};

declare function f:compileGreenfox_addResourceShapeIds($gfox as element(gx:greenfox)) {
    f:compileGreenfox_addResourceShapeIdsRC($gfox)
};

declare function f:compileGreenfox_addResourceShapeIdsRC($n as node()) {
    typeswitch($n)
    
    (: `file` and `folder` are just copied :)
    case element(gx:file) | element(gx:folder) return
        element {node-name($n)} {
            i:copyNamespaceNodes($n),
            $n/@* ! f:compileGreenfox_addResourceShapeIdsRC(.),
            $n/node() ! f:compileGreenfox_addResourceShapeIdsRC(.)
        }
     
    (: Special treatment of `TargetSize` obsolete
    
    (: TargetSize - add @resourceShapeID :)        
    case element(gx:targetSize) return
        let $resourceShapeID := $n/ancestor::*[self::gx:file, self::gx:folder][1]/@resourceShapeID
        return
            element {node-name($n)} {
                i:copyNamespaceNodes($n),
                $resourceShapeID,
                $n/@* ! f:compileGreenfox_addResourceShapeIdsRC(.),
                $n/node() ! f:compileGreenfox_addResourceShapeIdsRC(.)
            }
    :)
    
    (: Divers elements - add @resourceShapeID :)
    case element() return
        let $resourceShapeID :=
            if ($n/(self::gx:docTree,
                    self::gx:hyperdocTree,
                    self::gx:foxvalue,
                    self::gx:foxvalues,
                    self::gx:foxvaluePair, 
                    self::gx:foxvaluePairs,
                    self::gx:foxvalueCompared,
                    self::gx:foxvaluesCompared,                    
                    self::gx:value,
                    self::gx:values,
                    self::gx:valuePair,
                    self::gx:valuePairs,
                    self::gx:valueCompared,
                    self::gx:valuesCompared,                    
                    self::gx:xpath,
                    self::gx:foxpath,
                    self::gx:links,   
                    self::gx:targetSize,
                    self::gx:fileName,                    
                    self::gx:fileSize, 
                    self::gx:fileDate, 
                    self::gx:mediatype,
                    self::gx:contentCorrespondence,
                    self::gx:content,
                    self::gx:docSimilar,
                    self::gx:folderSimilar,
                    self::gx:folderContent,
                    self::gx:xsdValid)) then  
                $n/ancestor::*[self::gx:file, self::gx:folder][1]/(@resourceShapeID, @resourceShapePath)
            else ()                
        return
            element {node-name($n)} {
                i:copyNamespaceNodes($n),
                $resourceShapeID,
                $n/@* ! f:compileGreenfox_addResourceShapeIdsRC(.),
                $n/node() ! f:compileGreenfox_addResourceShapeIdsRC(.)
            }
    default return $n        
};

(: ============================================================================
 :
 :     f u n c t i o n s    c u r r e n t l y    n o t    u s e d
 :
 : ============================================================================ :)

(:~
 : Inspects a component and returns another component which it references, 
 : or the original component if it does not reference another component. 
 : A reference is expressed by an @ref attribute. The referenced component 
 : is the checklib element with an @id attribute matching the value of @ref 
 : and with a local name matching the local name of the referencing component.
 :
 : NOTE: This function is currently not used.
 :
 : @param gxComponent a component possibly referencing another component
 : @return the original component, if it does not have a reference, or the
 :   referenced component
 :)
declare function f:compileGreenfox_resolveReference($gxComponent as element()) as element() {
    if (not($gxComponent/@ref)) then $gxComponent else
    
    let $gxname := local-name($gxComponent)
    let $target := $gxComponent/root()//gx:checklib/*[local-name(.) eq $gxname][@id eq $gxComponent/@ref]
    return
        $target
};



