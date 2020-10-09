# Greenfox
A command-line tool for validating filesystem trees against a Greenfox schema.

Introduction: [An introduction to Greenfox](declarative-amsterdam-2020/an-troduction-to-greenfox)

Schema examples:

- [amsterdam-tutorial](declarative-amsterdam-2020/schema)
- [amsterdam-demo1](declarative-amsterdam-2020/demo-constraint)
- [amsterdam-demo2](declarative-amsterdam-2020/demo-link)
- [amsterdam-demo3](declarative-amsterdam-2020/demo-mediatype)
- [example-schemas](example-schemas)

IMPORTANT: Greenfox requires **BaseX version 9.4.3** or newer - please download from [BaseX](https://basex.org/download/)

----------
Notes for participants of the **Greenfox Tutorial at Declarative Amsterdam 2020**:

The tutorial material **will be completed in the following days**. Frequent updates to be expected. Another note follows when completion is done.

Where to find what:

- Tutorial material here: [$greenfox/declarative-amsterdam-2020](declarative-amsterdam-2020)
- Installation hints here: [$greenfox/declarative-amsterdam-2020/install/README.INSTALL.txt](https://raw.githubusercontent.com/hrennau/greenfox/master/declarative-amsterdam-2020/install/README.INSTALL.txt)
----------



A **Greenfox schema** is a set of conditions constraining a **file system tree**. 
The file system tree can be **validated** against the schema, using **gfox**, the greenfox processor. 
The result of validation is a **validation report**. A validation report indicates **conformance** - 
whether the file system tree conforms to the schema - and it supplies **validation results** or **result statistics**. 

Use options `-[123rw]` in order to select a report type:

- `-1` = report type "Statistics short" (no resources listed)
- `-2` = report type "Statistics standard" (red resources listed)
- `-3` = report type "Statistics long" (red and green resources listed)
- `-r` = report type "Red" (all validation results for red resources, grouped by resource) 
- `-w` = report type "White" (all validation results, grouped by resource)

Use options `-[CR]` in order to filter validation results:

- `-C constraintFilter` = report only results matching the specified constraint name filters
- `-R resourceFilter`   = report only results matching the specified resource name filters

Usage:

```
   gfox path-to-schema [path-to-domain] [-123rw] [-C constraintFilter] [-R resourceFilter]
```

- `path-to-schema` - relative or absolute path of the Greenfox schema file
- `path-to-domain` - relative or absolute path of the root folder of the file system tree to be validated

Example calls:
```
gfox ../schema/air01.gfox.xml
gfox ../schema/air01.gfox.xml -1
gfox ../schema/air01.gfox.xml -3
gfox ../schema/air01.gfox.xml -r
gfox ../schema/air01.gfox.xml -r -C "*count closed ~target*"
gfox ../schema/air01.gfox.xml -r -R "*.json *.csv ~*log*"
gfox ../schema/air01.gfox.xml /path/to/domain
gfox ../schema/air01.gfox.xml /path/to/domain -r
```

For further introductory material see in the [xmlprague2020 folder](documentation/xmlprague-2020):

- greenfox-xmlprague-2020.pdf
- greenfox-xmlprague-2020.pptx





