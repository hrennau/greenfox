(:
 : greenfox - 
 :
 : @version 2020-02-13T18:25:58.784+01:00 
 :)

import module namespace tt="http://www.ttools.org/xquery-functions" at
    "tt/_docs.xqm",
    "tt/_help.xqm",
    "tt/_pcollection.xqm",
    "tt/_request.xqm";

import module namespace a1="http://www.greenfox.org/ns/xquery-functions" at
    "greenfoxTemplates.xqm",
    "validate.xqm";

declare namespace m="http://www.greenfox.org/ns/xquery-functions";
declare namespace z="http://www.greenfox.org/ns/structure";
declare namespace zz="http://www.ttools.org/structure";

declare variable $request as xs:string external;

(: tool scheme 
   ===========
:)
declare variable $toolScheme :=
<topicTool name="greenfox">
  <operations>
    <operation name="_dcat" func="getRcat" type="element()" mod="tt/_docs.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="docs" type="catDFD*" sep="SC" pgroup="input"/>
      <param name="dox" type="catFOX*" fct_minDocCount="1" sep="SC" pgroup="input"/>
      <pgroup name="input" minOccurs="1"/>
    </operation>
    <operation name="_docs" func="getDocs" type="element()+" mod="tt/_docs.xqm" namespace="http://www.ttools.org/xquery-functions">
      <pgroup name="input" minOccurs="1"/>
      <param name="doc" type="docURI*" sep="WS" pgroup="input"/>
      <param name="docs" type="docDFD*" sep="SC" pgroup="input"/>
      <param name="dox" type="docFOX*" fct_minDocCount="1" sep="SC" pgroup="input"/>
      <param name="dcat" type="docCAT*" sep="WS" pgroup="input"/>
      <param name="fdocs" type="docSEARCH*" sep="SC" pgroup="input"/>
    </operation>
    <operation name="_doctypes" func="getDoctypes" type="node()" mod="tt/_docs.xqm" namespace="http://www.ttools.org/xquery-functions">
      <pgroup name="input" minOccurs="1"/>
      <param name="doc" type="docURI*" sep="WS" pgroup="input"/>
      <param name="docs" type="docDFD*" sep="SC" pgroup="input"/>
      <param name="dox" type="docFOX*" fct_minDocCount="1" sep="SC" pgroup="input"/>
      <param name="dcat" type="docCAT*" sep="WS" pgroup="input"/>
      <param name="fdocs" type="docSEARCH*" sep="SC" pgroup="input"/>
      <param name="attNames" type="xs:boolean" default="false"/>
      <param name="elemNames" type="xs:boolean" default="false"/>
      <param name="sortBy" type="xs:string?" fct_values="name,namespace" default="name"/>
    </operation>
    <operation name="_search" type="node()" func="search" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
      <param name="query" type="xs:string?"/>
    </operation>
    <operation name="_searchCount" type="item()" func="searchCount" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
      <param name="query" type="xs:string?"/>
    </operation>
    <operation name="_createNcat" type="node()" func="createNcat" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
    </operation>
    <operation name="_feedNcat" type="node()" func="feedNcat" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
      <param name="doc" type="docURI*" sep="WS"/>
      <param name="docs" type="catDFD*" sep="SC"/>
      <param name="dox" type="catFOX*" sep="SC"/>
      <param name="path" type="xs:string?"/>
    </operation>
    <operation name="_copyNcat" type="node()" func="copyNcat" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI?" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
      <param name="query" type="xs:string?"/>
      <param name="toNodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
    </operation>
    <operation name="_deleteNcat" type="node()" func="deleteNcat" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="nodl" type="docURI" fct_rootElem="Q{{http://www.infospace.org/pcollection}}nodl"/>
    </operation>
    <operation name="_nodlSample" type="node()" func="nodlSample" mod="tt/_pcollection.xqm" namespace="http://www.ttools.org/xquery-functions">
      <param name="model" type="xs:string?" fct_values="xml, sql, mongo" default="xml"/>
    </operation>
    <operation name="template" type="node()" func="templateOp" mod="greenfoxTemplates.xqm" namespace="http://www.greenfox.org/ns/xquery-functions">
      <param name="domain" type="xs:string?" pgroup="input"/>
      <param name="folder" type="xs:string?" pgroup="input"/>
      <param name="folder2" type="xs:string?"/>
      <param name="file" type="xs:string?" pgroup="input"/>
      <param name="file2" type="xs:string?" pgroup="input"/>
      <param name="empty" type="xs:string*" fct_values="folder, folder2, file, file2"/>
      <param name="mfolder" type="xs:string?"/>
      <param name="mfolder2" type="xs:string?"/>
      <param name="mfile" type="xs:string?"/>
      <param name="mfile2" type="xs:string?"/>
      <pgroup name="input" minOccurs="1"/>
    </operation>
    <operation name="validate" type="node()" func="validateOp" mod="validate.xqm" namespace="http://www.greenfox.org/ns/xquery-functions">
      <param name="gfox" type="docFOX" fct_minDocCount="1" fct_maxDocCount="1" sep="WS" pgroup="input"/>
      <param name="domain" type="xs:string?"/>
      <param name="params" type="xs:string?"/>
      <param name="reportType" type="xs:string?" fct_values="white, red, whiteTree, redTree, std" default="redTree"/>
      <param name="format" type="xs:string?" default="xml"/>
      <pgroup name="input" minOccurs="1"/>
    </operation>
    <operation name="_help" func="_help" mod="tt/_help.xqm">
      <param name="default" type="xs:boolean" default="false"/>
      <param name="type" type="xs:boolean" default="false"/>
      <param name="mode" type="xs:string" default="overview" fct_values="overview, scheme"/>
      <param name="ops" type="nameFilter?"/>
    </operation>
  </operations>
  <types/>
  <facets/>
</topicTool>;

declare variable $req as element() := tt:loadRequest($request, $toolScheme);


(:~
 : Executes pseudo operation '_storeq'. The request is stored in
 : simplified form, in which every parameter is represented by a 
 : parameter element whose name captures the parameter value
 : and whose text content captures the (unitemized) parameter 
 : value.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__storeq($request as element())
        as node() {
    element {node-name($request)} {
        attribute crTime {current-dateTime()},
        
        for $c in $request/* return
        let $value := replace($c/@paramText, '^\s+|\s+$', '', 's')
        return
            element {node-name($c)} {$value}
    }       
};

    
(:~
 : Executes operation '_dcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__dcat($request as element())
        as element() {
    tt:getRcat($request)        
};
     
(:~
 : Executes operation '_docs'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__docs($request as element())
        as element()+ {
    tt:getDocs($request)        
};
     
(:~
 : Executes operation '_doctypes'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__doctypes($request as element())
        as node() {
    tt:getDoctypes($request)        
};
     
(:~
 : Executes operation '_search'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__search($request as element())
        as node() {
    tt:search($request)        
};
     
(:~
 : Executes operation '_searchCount'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__searchCount($request as element())
        as item() {
    tt:searchCount($request)        
};
     
(:~
 : Executes operation '_createNcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__createNcat($request as element())
        as node() {
    tt:createNcat($request)        
};
     
(:~
 : Executes operation '_feedNcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__feedNcat($request as element())
        as node() {
    tt:feedNcat($request)        
};
     
(:~
 : Executes operation '_copyNcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__copyNcat($request as element())
        as node() {
    tt:copyNcat($request)        
};
     
(:~
 : Executes operation '_deleteNcat'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__deleteNcat($request as element())
        as node() {
    tt:deleteNcat($request)        
};
     
(:~
 : Executes operation '_nodlSample'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__nodlSample($request as element())
        as node() {
    tt:nodlSample($request)        
};
     
(:~
 : Executes operation 'template'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_template($request as element())
        as node() {
    a1:templateOp($request)        
};
     
(:~
 : Executes operation 'validate'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation_validate($request as element())
        as node() {
    a1:validateOp($request)        
};
     
(:~
 : Executes operation '_help'.
 :
 : @param request the request element
 : @return the operation result
 :)
declare function m:execOperation__help($request as element())
        as node() {
    tt:_help($request, $toolScheme)        
};

(:~
 : Executes an operation.
 :
 : @param req the operation request
 : @return the result of the operation
 :)
declare function m:execOperation($req as element())
      as item()* {
    if ($req/self::zz:errors) then tt:_getErrorReport($req, 'Invalid call', 'code', ()) else
    if ($req/@storeq eq 'true') then m:execOperation__storeq($req) else
    
    let $opName := tt:getOperationName($req) 
    let $result :=    
        if ($opName eq '_help') then m:execOperation__help($req)
        else if ($opName eq '_dcat') then m:execOperation__dcat($req)
        else if ($opName eq '_docs') then m:execOperation__docs($req)
        else if ($opName eq '_doctypes') then m:execOperation__doctypes($req)
        else if ($opName eq '_search') then m:execOperation__search($req)
        else if ($opName eq '_searchCount') then m:execOperation__searchCount($req)
        else if ($opName eq '_createNcat') then m:execOperation__createNcat($req)
        else if ($opName eq '_feedNcat') then m:execOperation__feedNcat($req)
        else if ($opName eq '_copyNcat') then m:execOperation__copyNcat($req)
        else if ($opName eq '_deleteNcat') then m:execOperation__deleteNcat($req)
        else if ($opName eq '_nodlSample') then m:execOperation__nodlSample($req)
        else if ($opName eq 'template') then m:execOperation_template($req)
        else if ($opName eq 'validate') then m:execOperation_validate($req)
        else if ($opName eq '_help') then m:execOperation__help($req)
        else
        tt:createError('UNKNOWN_OPERATION', concat('No such operation: ', $opName), 
            <error op='{$opName}'/>)    
     let $errors := if ($result instance of node()+) then tt:extractErrors($result) else ()     
     return
         if ($errors) then tt:_getErrorReport($errors, 'System error', 'code', ())     
         else $result
};

m:execOperation($req)
    