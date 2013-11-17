import ceylon.file { Writer, parsePath, File, Resource, Nil }
shared void generate() {
    Resource resource = parsePath("source/ceylon/formatter/options/FormattingOptions.ceylon").resource;
    File file;
    if (is Nil resource) {
        file = resource.createFile();
    } else {
        assert (is File resource);
        file = resource;
    }
    Writer writer = file.Overwriter();
    try {
        writeHeader(writer);
        writeImports(writer);
        generateSparseFormattingOptions(writer);
        generateFormattingOptions(writer);
        generateCombinedOptions(writer);
        generateVariableOptions(writer);
        generateFormattingFile(writer);
    } finally {
        writer.close(null);
    }
}

void writeHeader(Writer writer) {
    writer.write(
        "/*
          * DO NOT MODIFY THIS FILE
          *
          * It is generated by the source_gen.ceylon.formatter module (folder source-gen),
          * specifically the formattingOptions package therein.
          */
         
         ");
}

void writeImports(Writer writer) {
    writer.write(
        "import ceylon.file { File, Reader, parsePath }
         
         ");
}

void generateSparseFormattingOptions(Writer writer) {
    writer.write(
        "\"A superclass of [[FormattingOptions]] where attributes are optional.
         
          The indented use is that users take a \\\"default\\\" `FormattingOptions` object and apply some
          `SparseFormattingOptions` on top of it using [[CombinedOptions]]; this way, they don't have
          to specify every option each time that they need to provide `FormattingOptions` somewhere.\"\n");
    writer.write("shared class SparseFormattingOptions(");
    variable Boolean needsComma = false;
    for (option in formattingOptions) {
        if (needsComma) {
            writer.write(",");
        }
        writer.write("\n        ``option.name`` = null");
        needsComma = true;
    }
    writer.write(") {\n");
    for (option in formattingOptions) {
        String[] lines = [*option.documentation.split((Character c) => c == '\n')];
        if (lines.size == 0 || option.documentation == "") {
            writer.write("\n");
        }
        else if (lines.size == 1) {
            writer.write("\n    \"``option.documentation``\"\n");
        } else {
            assert(exists firstLine = lines.first);
            assert(exists lastLine = lines.last);
            writer.write("\n    \"``firstLine``\n");
            if (lines.size > 2) {
                for (String line in lines[1..lines.size-2]) {
                    writer.write("     ``line``\n");
                }
            }
            writer.write("     ``lastLine``\"\n");
        }
        writer.write("    shared default ``option.type``? ``option.name``;\n");
    }
    writer.write("}\n\n");
}

void generateFormattingOptions(Writer writer) {
    writer.write(
        "\"A bundle of options for the formatter that control how the code should be formatted.
         
          The default arguments are modeled after the `ceylon.language` module and the Ceylon SDK.
          You can refine them using named arguments:
          
              FormattingOptions {
                  indentMode = Tabs(4);
                  // modify some others
                  // keep the rest
              }\"\n");
    writer.write("shared class FormattingOptions(");
    variable Boolean needsComma = false;
    for (option in formattingOptions) {
        if (needsComma) {
            writer.write(",");
        }
        writer.write("\n        ``option.name`` = ``option.defaultValue``");
        needsComma = true;
    }
    writer.write(") extends SparseFormattingOptions() {\n");
    for (option in formattingOptions) {
        writer.write("\n    shared actual default ``option.type`` ``option.name``;\n");
    }
    writer.write("}\n\n");
}

void generateCombinedOptions(Writer writer) {
    writer.write(
        "\"A combination of several [[FormattingOptions]], of which some may be [[Sparse|SparseFormattingOptions]].
         
          Each attribute is first searched in each of the [[decoration]] options, in the order of their appearance,
          and, if it isn't present in any of them, the attribute of [[baseOptions]] is used.
          
          In the typical use case, `foundation` will be some default options (e.g. `FormattingOptions()`), and 
          `decoration` will be one `SparseFormattingOptions` object created on the fly:
          
              FormattingVisitor(tokens, writer, CombinedOptions(defaultOptions,
                  SparseFormattingOptions {
                      indentMode = Mixed(Tabs(8), Spaces(4));
                      // ...
                  }));\"\n");
    writer.write("shared class CombinedOptions(FormattingOptions baseOptions, SparseFormattingOptions+ decoration) extends FormattingOptions() {\n");
    for(option in formattingOptions) {
        writer.write("\n    shared actual ``option.type`` ``option.name`` {\n");
        writer.write("        for (options in decoration) {\n");
        writer.write("            if (exists option = options.``option.name``) {\n");
        writer.write("                return option;\n");
        writer.write("            }\n");
        writer.write("        }\n");
        writer.write("        return baseOptions.``option.name``;\n");
        writer.write("    }\n");
    }
    writer.write("}\n\n");
}

void generateVariableOptions(Writer writer) {
    writer.write(
        "\"A subclass of [[FormattingOptions]] that makes its attributes [[variable]].
          
          For internal use only.\"\n");
    writer.write("class VariableOptions(FormattingOptions baseOptions) extends FormattingOptions() {\n\n");
    for(option in formattingOptions) {
        writer.write("    shared actual variable ``option.type`` ``option.name`` = baseOptions.``option.name``;\n");
    }
    writer.write("}\n\n");
}

void generateFormattingFile(Writer writer) {
    writer.write(
        "\"Reads a file with formatting options.
          
          The file consists of lines of key=value pairs or comments, like this:
          ~~~~plain
          # Boss Man says the One True Style is evil
          blockBraceOnNewLine=true
          # 80 characters is not enough
          maxLineWidth=120
          indentMode=4 spaces
          ~~~~
          As you can see, comment lines begin with a `#` (`\\\\{0023}`), and the value
          doesn't need to be quoted to contain spaces. Blank lines are also allowed.
          
          The keys are attributes of [[FormattingOptions]].
          The format of the value depends on the type of the key; to parse it, the
          function `parse<KeyType>(String)` is used (e.g [[ceylon.language::parseInteger]]
          for `Integer` values, [[ceylon.language::parseBoolean]] for `Boolean` values, etc.).
          
          A special option in this regard is `include`: It is not an attribute of
          `FormattingOptions`, but instead specifies another file to be loaded.
          
          The file is processed in the following order:
          
          1. First, load [[baseOptions]].
          2. Then, scan the file for any `include` options, and process any included files.
          3. Lastly, parse all other lines.
          
          Thus, options in the top-level file override options in included files.
          
          For another function which does exactly the same thing in a different way,
          see [[formattingFile_meta]].\"
         shared FormattingOptions formattingFile(
             \"The file to read\"
             String filename,
             \"The options that will be used if the file and its included files
              don't specify an option\"
             FormattingOptions baseOptions = FormattingOptions())
                 => variableFormattingFile(filename, baseOptions);
         
         ");
    
    writer.write(
        "\"An internal version of [[formattingFile]] that specifies a return type of [[VariableOptions]],
          which is needed for the internally performed recursion.\"
         VariableOptions variableFormattingFile(String filename, FormattingOptions baseOptions) {
             
             if (is File file = parsePath(filename).resource) {
                 // read the file
                 Reader reader = file.Reader();
                 variable String[] lines = [];
                 while (exists line = reader.readLine()) {
                     lines = [line, *lines];
                 }
                 lines = lines.reversed; // since we had to read the file in reverse order
                 
                 // read included files
                 variable VariableOptions options = VariableOptions(baseOptions);
                 for (String line in lines) {
                     if (line.startsWith(\"include=\")) {
                         options = variableFormattingFile(line[\"include=\".size...], options);
                     }
                 }
                 
                 // read other options
                 for (String line in lines) {
                     if (!line.startsWith(\"#\") && !line.startsWith(\"include=\")) {
                         Integer? indexOfEquals = line.indexes((Character c) => c == '=').first;
                         \"Line does not contain an equality sign\"
                         assert (exists indexOfEquals);
                         String optionName = line.segment(0, indexOfEquals);
                         String optionValue = line.segment(indexOfEquals + 1, line.size - indexOfEquals - 1);
                         
                         switch (optionName)\n");
    for (FormattingOption option in formattingOptions) {
        writer.write(
            "                case (\"``option.name``\") {\n");
        if (!option.type.endsWith("?")) {
            writer.write(
                "                    if (exists option = parse``option.type``(optionValue)) {
                                         options.``option.name`` = option;
                                     } else {
                                         throw Exception(\"Can't parse value '\`\`optionValue\`\`' for option ``option.name``!\");
                                     }\n");
        } else {
            writer.write(
                "                    options.``option.name`` = parse``option.type.trimTrailing((Character c) => c == '?')``(optionValue);\n");
        }
        writer.write(
            "                }\n");
             
    }
    writer.write(
        "                else {
                             throw Exception(\"Unknown option '\`\`optionName\`\`'!\");
                         }
                     }
                 }
                 
                 return options;
             } else {
                 throw Exception(\"File '\`\`filename\`\` not found!\");
             }
         }");
}
