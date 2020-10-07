(:
 : -------------------------------------------------------------------------
 :
 : docSimilarConstraintReports.xqm - functions reporting results of document comparisons
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath.xqm";    
    
declare namespace gx="http://www.greenfox.org/ns/schema";
declare namespace fox="http://www.foxpath.org/ns/annotations";


declare function f:docSimilarConstraintReports(
                             $constraintElem as element(),
                             $d1 as node(),
                             $d2 as node(),
                             $colour as xs:string)
        as element()* {
    let $redReports := 
        let $control := $constraintElem/@redReport
        return
            if (not($control)) then 'localIndexedPath' else $constraintElem/@redReport/tokenize(.)
    let $report :=
        for $redReport in $redReports
        return
            if ($redReport = ('localPath', 'localIndexedPath')) then
                let $fn_path := 
                    switch($redReport)
                    case 'localPath' return f:localPathWithData#1
                    case 'localIndexedPath' return f:localIndexedPathWithData#1
                    default return error()
                let $pathFormat := $redReport                    
                let $pathsAndData1 := $d1//*/(., @*)/$fn_path(.) => distinct-values()
                let $pathsAndData2 := $d2//*/(., @*)/$fn_path(.) => distinct-values()
                let $paths1 := $pathsAndData1 ! replace(., '=.*', '')
                let $paths2 := $pathsAndData2 ! replace(., '=.*', '')
                let $pathsOnly1 := $paths1[not(. = $paths2)]
                let $pathsOnly2 := $paths2[not(. = $paths1)]
                let $pathsBoth := $paths1[. = $paths2]
                let $dataDiffs :=
                    for $path in $pathsBoth
                    let $path_ := $path ! replace(., '[\[\]$(){}]', '\\$0', 's')
                    let $data1 := $pathsAndData1[matches(., $path_||'=')] ! substring-after(., '=')
                    let $data2 := $pathsAndData2[matches(., $path_||'=')] ! substring-after(., '=')
                    where $data1 ne $data2
                    return
                        <dataDiff path="{$path}">{
                            <data1>{$data1}</data1>,
                            <data2>{$data2}</data2>
                        }</dataDiff>
                return
                    <gx:paths pathFormat="{$pathFormat}">{
                        if (empty($pathsOnly1)) then () else
                        <gx:only1 count="{count($pathsOnly1)}">{
                            ($pathsOnly1 => sort()) ! <gx:path>{.}</gx:path>
                        }</gx:only1>,                    
                        if (empty($pathsOnly2)) then () else
                        <gx:only2 count="{count($pathsOnly2)}">{
                            ($pathsOnly2 => sort()) ! <gx:path>{.}</gx:path>
                        }</gx:only2>,
                        if (not($dataDiffs)) then () else
                        <dataDiffs count="{count($dataDiffs)}">{
                            $dataDiffs
                        }</dataDiffs>
                    }</gx:paths>
            else ()                    
    return $report                
};

(:~
 : A simple data path representation, using local names
 : and ignoring indexes.
 :
 : @param a node
 : @return the path string
 :)
declare function f:localPath($node as node())
        as xs:string {
    $node/ancestor-or-self::node()
    /concat(self::attribute()/'@', local-name(.))
    => string-join('/')
};        

(:~
 : Representation of a node consisting of a local path,
 : optionally followed by an equality sign and the node 
 : string value.
 :
 : @param a node
 : @return the path string
 :)
declare function f:localPathWithData($node as node())
        as xs:string {
    let $path := f:localPath($node)
    let $data := 
        typeswitch($node)
        case element() return $node[not(*)]/string()
        case attribute() return $node/string()
        default return ()
    return
        string-join(($path, $data), '=')
};        

(:~
 : A simple data path representation, using local names
 : and indexes, yet suppressing index "1".
 :
 : @param a node
 : @return the path string
 :)
declare function f:localIndexedPath($node as node())
        as xs:string {
    (
    for $n in $node/ancestor-or-self::node()
    let $indexSuffix :=
        if ($n instance of document-node()) then () else
            let $index := ($n/preceding-sibling::*[local-name(.) eq $n/local-name(.)] => count()) + 1
            return '[' || $index || ']'
    return
        $n/concat(self::attribute()/'@', local-name(.), $indexSuffix)
    ) => string-join('/')
};        

(:~
 : A simple data path representation, using local names
 : and ignoring indexes.
 :
 : @param a node
 : @return the path string
 :)
declare function f:localIndexedPathWithData($node as node())
        as xs:string {
    let $path := f:localIndexedPath($node)
    let $data := 
        typeswitch($node)
        case element() return $node[not(*)]/string()
        case attribute() return $node/string()
        default return ()
    return
        string-join(($path, $data), '=')
};        

