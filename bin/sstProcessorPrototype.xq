declare variable $sstdef external := '/projects/sap/projects/sst/example-sst-op-config.xml';
declare variable $sdoc external := '/projects/sap/projects/sst/example-sst-input-01.xml';


let $indoc := doc($sdoc)
return $indoc