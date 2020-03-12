(:
 : -------------------------------------------------------------------------
 :
 : resourceAccess.xqm - functions accessing resource contents and resource properties
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" at 
    "tt/_foxpath-uri-operations.xqm";
    
declare namespace z="http://www.ttools.org/gfox/ns/structure";
declare namespace gx="http://www.greenfox.org/ns/schema";

(:~
 : Returns a string representation of a resource.
 :
 : @param uri the URI or file path of the resource
 : @param encoding the encoding of the resource content
 : @param options options controlling the evaluation
 : @return the text of the resource, or the empty sequence if retrieval fails
 :)
declare function f:foxUnparsedText($uri as xs:string, 
                                   $encoding as xs:string?, 
                                   $options as map(*)?)
        as xs:string? {
    tt:fox-unparsed-text($uri, $encoding, $options)        
};

(:~
 : Returns an XML document identified by URI or file path.
 :
 : @param uri the URI or file path of the resource
 : @param options options controlling the evaluation
 : @return the document, or the empty sequence if retrieval or parsing fails
 :)
declare function f:foxDoc($uri as xs:string, 
                          $options as map(*)?)
        as document-node()? {
    tt:fox-doc($uri, $options)        
};

(:~
 : Returns an XML representation of the CSV record identified by URI or file path.
 :
 : @param uri the URI or file path of the resource
 : @param separator the separator character (or token `comma` or token `semicolon`)
 : @param withHeader if 'yes', the first row contains column headers
 : @param names if 'direct', column names are used as element names;
 :              if 'attributes', column names are provided by @name
 : @param withQuotes if 'yes', quotes at start and end of field are treated as control characters
 : @param backslashes if 'yes', \n, \t and \r are replaced by the corresponding control characters
 : @param options options controlling the evaluation
 : @return an XML document representing JSON data, or the empty sequence if 
 :     retrieval or parsing fails
 :)
declare function f:foxCsvDoc($uri as xs:string,
                             $separator as xs:string,
                             $withHeader as xs:string,
                             $names as xs:string,
                             $withQuotes as xs:string,
                             $backslashes as xs:string,
                             $options as map(*)?)
        as document-node()? {
    tt:fox-csv-doc($uri, $separator, $withHeader, $names, $withQuotes, $backslashes, $options)
};

(:~
 : Returns an XML representation of the CSV record identified by URI or file path.
 :
 : @param filePath the file path
 : @param params an element which may have attributes controllig the parsing
 : @return the csv document, or the empty sequence of parsing is not successful
 :)
declare function f:csvDoc($filePath as xs:string, $params as element())
        as document-node()? {
    let $separator := ($params/@csv.separator, 'comma')[1]
    let $withHeader := ($params/@csv.withHeader, 'no')[1]
    let $names := ($params/@csv.names, 'direct')[1]
    let $withQuotes := ($params/@csv.withQuotes, 'yes')[1]
    let $backslashes := ($params/@csv.backslashes, 'no')[1]
    return
        f:foxCsvDoc($filePath, $separator, $withHeader, $names, $withQuotes, $backslashes, ())
};   



