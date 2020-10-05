(:
 : -------------------------------------------------------------------------
 :
 : constants.xqm - Document me!
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
    
declare namespace z="http://www.ttools.org/greenfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

declare variable $f:URI_XSD := 'http://www.w3.org/2001/XMLSchema';
declare variable $f:URI_GX := 'http://www.greenfox.org/ns/schema';
declare variable $f:URI_GXERR := 'http://www.greenfox.org/ns/error';
declare variable $f:PREFIX_GX := 'gx';

declare variable $f:DEBUG_LEVEL := 0;
declare variable $f:DEBUG_FOLDER := '.';
declare variable $f:DEBUG_TAGS := 
    'linksxxx'
    => tokenize();

