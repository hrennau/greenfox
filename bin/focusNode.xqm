(:
 : -------------------------------------------------------------------------
 :
 : focusNode.xqm - validates the focus nodes selected by gx:focusNode
 :
 : -------------------------------------------------------------------------
 :)
 
module namespace f="http://www.greenfox.org/ns/xquery-functions";
import module namespace tt="http://www.ttools.org/xquery-functions" 
at "tt/_foxpath.xqm";    

import module namespace i="http://www.greenfox.org/ns/xquery-functions" 
at "constants.xqm",
   "expressionEvaluator.xqm",
   "extensionValidator.xqm",
   "fileShape.xqm",
   "greenfoxUtil.xqm";

declare namespace gx="http://www.greenfox.org/ns/schema";

