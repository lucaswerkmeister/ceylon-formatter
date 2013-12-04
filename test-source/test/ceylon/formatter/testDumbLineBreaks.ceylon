import ceylon.test { test }
import ceylon.formatter { FormattingWriter, maxDesire }
import ceylon.formatter.options { parseLineBreakStrategy, FormattingOptions, LineBreakStrategy }
import ceylon.file { Writer }

test
shared void testDumbLineBreaks() {
    object writer satisfies Writer {
        shared actual void destroy() {}        
        shared actual void flush() {}        
        shared actual void write(String string) {}        
        shared actual void writeLine(String line) {}
    }
    FormattingWriter w = FormattingWriter(null, writer, FormattingOptions());
    
    LineBreakStrategy? dumbLineBreaks = parseLineBreakStrategy("dumb");
    assert (exists dumbLineBreaks);
    
    assert(exists location1 = dumbLineBreaks.lineBreakLocation([
        w.Token("breakHere", false, 1, maxDesire, maxDesire),
        *{
            for (i in 1..10)
                w.Token("noBreakHere``i``", true, null, maxDesire, maxDesire)
        }], 0, 20), location1 == 1);
    
    assert(is Null n = dumbLineBreaks.lineBreakLocation([
        for (i in 1..10)
            w.Token("noBreakHere``i``", false, null, maxDesire, maxDesire)
        ], 0, 20));
        
    SequenceBuilder<FormattingWriter.QueueElement> s = SequenceBuilder<FormattingWriter.QueueElement>();
    for (i in 1..10) {
        s.append(w.Token("noBreakHere``i``", false, null, maxDesire, maxDesire));
    }
    s.append(w.LineBreak());
    assert(exists location2 = dumbLineBreaks.lineBreakLocation(s.sequence, 0, 20), location2 == 10);
}