# Greenfox
A command-line tool for validating filesystem trees against a Greenfox schema.


----------


Notes for participants of the **Greenfox Tutorial at Declarative Amsterdam 2020**, Oct 08, 14:00 - 15:30 

- Tutorial material found here: $greenfox/declarative-amsterdam-2020
- Installation hints foud here: $greenfox/declarative-amsterdam-2020/install/README.INSTALL.txt
- The material is preliminary and will change until Thursday.
- Please make sure to UPDATE your project on Wednesday, Oct 07, evening.
----------



A **Greenfox schema** is a set of conditions constraining a **file system tree**. 
The file system tree can be **validated** against the schema, using **gfox**, the greenfox processor. 
The result of validation is a **validation report**. A validation report indicates **conformance** - 
whether the file system tree conforms to the schema - and it supplies **validation results** or **result statistics**. 

Use options -[abcrw] in order to select a report type:

- -a = report type "Statistics short" (no resources listed)
- -b = report type "Statistics standard" (red resources listed)
- -c = report type "Statistics long" (red and green resources listed)
- -r = report type "Red" (all validation results for red resources, grouped by resource) 
- -w = report type "White" (all validation results, grouped by resource)

Usage:

```
   gfox [-abcrw] path-to-schema [path-to-domain]
```

- path-to-schema - relative or absolute path of the Greenfox schema file
- path-to-domain - relative or absolute path of the root folder of the file system tree to be validated

Example calls:
```
gfox ../schema/air01.gfox.xml
gfox -c ../schema/air01.gfox.xml
gfox -r ../schema/air01.gfox.xml
gfox /path/to/my.gfox.xml /path/to/domain
gfox  -w /path/to/my.gfox.xml /path/to/domain
gfox  -a /path/to/my.gfox.xml /path/to/domain
```

For an introduction see in the **documentation folder**:

- greenfox-xmlprague-2020.pdf
- greenfox-xmlprague-2020.pptx

More material to appear before Thursday, October 8, 2020.

For schema examples, see folder example-schemas.



