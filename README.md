# greenfox
A command-line tool for validating filesystem trees against a greenfox schema.

Note for participants of the **Greenfox Tutorial at Declarative Amsterdam 2020**, Oct 08, 14:00 - 15:30 -

   The contents of this project will still change until Thursday -
   please make sure to checkout again on Wednesday, Oct 07, evening
    
A **greenfox schema** is a set of conditions constraining a **file system tree**. 
The file system tree can be **validated** against the schema, using gfox, the greenfox processor. 
The result of validation is a **validation report**. A validation report indicates **conformance** - 
whether the file system tree conforms to the schema - and it supplies **validation results**. 
Each validation result describes the outcome of validating a single resource against a single 
constraint. 

Use options in order to select a report type:

- a - report type "Statistics short (no resources listed)
- b - report type "Statistics standard (red resources listed)
- c - report type "Statistics long (red and green resources listed)
- r - report type "Red" (all results for red resources, grouped by resource) 
- w - report type "White" (all results, grouped by resource)

Example calls:


```
gfox ../schema/air01.gfox.xml
gfox -c ../schema/air01.gfox.xml
gfox -r ../schema/air01.gfox.xml

```

For an introduction see in the **documentation folder**:

- greenfox-xmlprague-2020.pdf
- greenfox-xmlprague-2020.pptx
- greenfox-manual.docx

For schema examples, see folder example-schemas.



