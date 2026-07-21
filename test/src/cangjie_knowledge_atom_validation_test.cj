package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieKnowledgeAtomValidationTest {
    @TestCase public func p3Ut01DuplicateExecutionIsStable():Unit{let one=runKnowledgeAtomTestBundle(p3ValidBundle());let two=runKnowledgeAtomTestBundle(p3ValidBundle());@Expect(one.ok,true);@Expect(one.total,3);@Expect(one.passed,3);@Expect(one.knowledgeText,"General ArrayList and Rune usage 中文😀.");@Expect(one.example,"ArrayList<Rune> example 中文😀.");@Expect(two.passed,one.passed)}
    @TestCase public func p3Bnd01MissingCategoryAndMalformedUtf8SafeTextFailClosed():Unit{let missing=validateKnowledgeAtomTestBundle(p3Rehash(p3ValidBundle().replace(",${p3BoundaryTest()}","")));@Expect(missing.ok,false);@Expect(missing.diagnostic,"missing_atom_test_category");let candidate=CangjieBenchmarkGapInput();candidate.caseId="PUBLIC-BND";candidate.taskText="general gap";candidate.missingKnowledge="G-ARRAYLIST";candidate.officialCitation="https://docs.cangjie-lang.cn/docs/1.0.0/";candidate.knowledgeAtomCandidate=true;let candidates=ArrayList<CangjieBenchmarkGapInput>();candidates.add(candidate);@Expect(curateBenchmarkGapRecords(candidates).diagnostic,"atom_test_bundle_required");let unicode=runKnowledgeAtomTestBundle(p3ValidBundle());@Expect(unicode.ok,true);let malformed=validateKnowledgeAtomTestBundle("{\"knowledgeText\":\"中😀\"");@Expect(malformed.diagnostic,"malformed_atom_test_bundle")}
    @TestCase public func p3Pos01GeneralArrayListRuneAtomPassesCuration():Unit{let input=CangjieBenchmarkGapInput();input.caseId="PUBLIC-001";input.taskText="Use general ArrayList and Rune APIs.";input.compilerOutput="compile_error";input.missingKnowledge="G-ARRAYLIST";input.officialCitation="https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection";input.knowledgeAtomTestBundle=p3ValidBundle();let inputs=ArrayList<CangjieBenchmarkGapInput>();inputs.add(input);let curated=curateBenchmarkGapRecords(inputs);@Expect(curated.ok,true);@Expect(curated.accepted,1);@Expect(curated.records[0].recordKind,CangjieTypedRecordKinds.KNOWLEDGE_ATOM);@Expect(curated.records[0].chunk,"Knowledge: General ArrayList and Rune usage 中文😀.\nExample: ArrayList<Rune> example 中文😀.");@Expect(utf8SafePrefix(curated.records[0].chunk,80).contains("Knowledge: General ArrayList and Rune usage 中文😀."),true);@Expect(curated.records[0].metadata.derivedFrom[0],"knowledge-atom:G-ARRAYLIST-RUNE")}
    @TestCase public func p3Neg01ContaminationCitationAndTestFailureRejected():Unit{let contaminated=validateKnowledgeAtomTestBundle(p3Rehash(p3ValidBundle().replace("General ArrayList and Rune usage 中文😀.","CJ-HUMANEVAL-007 canonical_solution")));@Expect(contaminated.diagnostic,"atom_content_contamination");let fake=validateKnowledgeAtomTestBundle(p3Rehash(p3ValidBundle().replace("https://docs.cangjie-lang.cn/","https://docs.cangjie-lang.cn.evil.invalid/")));@Expect(fake.diagnostic,"atom_citation_not_allowed");let failed=runKnowledgeAtomTestBundle(p3Rehash(p3ValidBundle().replace("\"expected\":\"3\"","\"expected\":\"9\"")));@Expect(failed.ok,false);@Expect(failed.diagnostic,"atom_test_failed");let fakeHash=validateKnowledgeAtomTestBundle(p3ValidBundle().replace(cangjieKnowledgeAtomCandidateHash(p3ValidBundle()),"sha256:fake"));@Expect(fakeHash.diagnostic,"atom_candidate_hash_mismatch")}
    @TestCase public func p3Pos02TeacherEmpiricalRequiresRecomputableProvenance():Unit{let valid=runKnowledgeAtomTestBundle(p3TeacherEmpiricalBundle());@Expect(valid.ok,true);@Expect(valid.passed,3);let missing=validateKnowledgeAtomTestBundle(p3Rehash(p3TeacherEmpiricalBundle().replace("\"solutionBindingHash\":\"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\"","\"solutionBindingHash\":\"\"")));@Expect(missing.diagnostic,"unverified_teacher_empirical");let tampered=validateKnowledgeAtomTestBundle(p3Rehash(p3TeacherEmpiricalBundle().replace("\"passed\":3","\"passed\":2")));@Expect(tampered.diagnostic,"unverified_teacher_empirical")}
    @TestCase public func p3Pos02TeacherEmpiricalCurationKeepsSourceBoundary():Unit{
        let input=CangjieBenchmarkGapInput();input.sourceClass="teacher_empirical";input.caseId="PUBLIC-EMPIRICAL";input.taskText="General derived-key ordering failure.";input.compilerOutput="equal keys reordered";input.missingKnowledge="G-STABLE-DERIVED-KEY-ORDERING";input.knowledgeAtomCandidate=true;input.knowledgeAtomTestBundle=p3TeacherEmpiricalBundle();input.candidateHash="sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
        let inputs=ArrayList<CangjieBenchmarkGapInput>();inputs.add(input);let accepted=curateBenchmarkGapRecords(inputs)
        @Expect(accepted.ok,true);@Expect(accepted.accepted,1)
        @Expect(accepted.records[0].citation,"teacher-empirical://candidate/dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd")
        let proof=ckbBenchmarkGapProofForCandidate(accepted.records[0],"candidate-empirical","active-before")
        @Expect(proof.status,"passed");@Expect(proof.coveragePass,true);@Expect(proof.citationCount,1)
        input.sourceClass="";input.officialCitation="https://docs.cangjie-lang.cn/docs/1.0.0/";let rejected=curateBenchmarkGapRecords(inputs);@Expect(rejected.diagnostic,"atom_source_class_mismatch")
    }
    @TestCase public func p3Pos02AuthoritativeTeacherEmpiricalGapRoundTrips():Unit{let input=CangjieBenchmarkGapInput();input.schemaVersion="ckb-benchmark-gap-v1";input.datasetVersion="cangjie-humaneval-164-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";input.teacherRunId="teacher-empirical-r1";input.evidence="original failure plus completed run and experiment hashes";input.evidenceHash=benchmarkGapSha256(input.evidence);input.candidatePath="candidate-knowledge/ckb-benchmark-gap.jsonl";input.failureTaxonomy="unit_failure";input.knowledgeGapConfirmations=0;input.sourceClass="teacher_empirical";input.caseId="PUBLIC-EMPIRICAL-AUTH";input.taskText="General derived-key ordering failure.";input.compilerOutput="equal keys reordered";input.missingKnowledge="G-STABLE-DERIVED-KEY-ORDERING";input.interfaceId="KI-04";input.contentFamily="KC-01";input.updateMechanism="KU-11";input.targetVersion="1.0.0";input.knowledgeAtomCandidate=true;input.knowledgeAtomTestBundle=p3TeacherEmpiricalBundle();input.candidateHash=canonicalBenchmarkGapCandidateHash(input);let inputs=ArrayList<CangjieBenchmarkGapInput>();inputs.add(input);let accepted=curateBenchmarkGapRecords(inputs);@Expect(accepted.ok,true);@Expect(accepted.accepted,1);let rendered=renderAuthoritativeBenchmarkGapInput(input);@Expect(rendered.contains("\"sourceClass\":\"teacher_empirical\""),true);input.knowledgeAtomTestBundle=p3Rehash(input.knowledgeAtomTestBundle.replace("\"passed\":3","\"passed\":2"));input.candidateHash=canonicalBenchmarkGapCandidateHash(input);@Expect(curateBenchmarkGapRecords(inputs).diagnostic,"unverified_teacher_empirical")}

    // T-R0-UT / T-R0-POS: audit evidence remains accepted but never enters serving content or identity.
    @TestCase public func tR0UtServingProjectionExcludesAuditEnvelope():Unit{
        let input=p3AtomGap("CJ-HUMANEVAL-162");input.taskText="Task: benchmark-specific public prompt";input.visibleTestExcerpt="Visible tests: public examples";input.compilerOutput="Compiler output: solution.cj failed"
        let curated=curateBenchmarkGapRecords(p3AtomInputs([input]));@Expect(curated.ok,true);let record=curated.records[0]
        @Expect(record.recordKind,CangjieTypedRecordKinds.KNOWLEDGE_ATOM);@Expect(record.metadata.sourceSet,CangjieSourceSets.KNOWLEDGE_ATOMS);@Expect(record.sourceId.startsWith("knowledge-atom-"),true);@Expect(record.sourceId.startsWith("curated-gap-"),false);@Expect(record.title,"Knowledge atom G-ARRAYLIST-RUNE");@Expect(record.chunk,"Knowledge: General ArrayList and Rune usage 中文😀.\nExample: ArrayList<Rune> example 中文😀.")
        for(marker in ["CJ-HUMANEVAL","Task:","Visible tests:","Compiler output:","Missing knowledge:","Interface ID:","Update mechanism:"]){@Expect(record.title.contains(marker)||record.chunk.contains(marker)||record.metadata.path.contains(marker),false)}
        @Expect(record.metadata.path.startsWith("knowledge-atom/"),true);@Expect(record.metadata.symbol,"KI-02:G-ARRAYLIST-RUNE")
    }

    // T-R0-UT: every user-facing, test, purification and provenance field participates in the atom hash.
    @TestCase public func tR0UtCanonicalHashCoversWholeAtomEnvelope():Unit{
        let valid=p3TeacherEmpiricalBundle();@Expect(validateKnowledgeAtomTestBundle(valid).ok,true)
        for(tampered in [valid.replace("ordering","sorting"),valid.replace("Use a stable insertion step for equal keys.","Use a different example."),valid.replace("extractor-v1","extractor-v2"),valid.replace("purificationPassed\":true","purificationPassed\":false"),valid.replace("\"expected\":\"3\"","\"expected\":\"4\""),valid.replace("sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"),valid.replace("positive:ok;negative:ok;boundary:ok","changed:ok")]){
            @Expect(validateKnowledgeAtomTestBundle(tampered).diagnostic,"atom_candidate_hash_mismatch")
        }
    }

    // T-R2-UT / T-R2-POS: the same atom from different benchmark observations has one serving identity.
    @TestCase public func tR2UtSameAtomAcrossCasesDeduplicates():Unit{
        let first=p3AtomGap("CJ-HUMANEVAL-001");let second=p3AtomGap("CJ-HUMANEVAL-999");second.taskText="different audit task";second.compilerOutput="different audit compiler output"
        let curated=curateBenchmarkGapRecords(p3AtomInputs([first,second]));@Expect(curated.ok,true);@Expect(curated.records.size,1);@Expect(curated.duplicates,1)
        @Expect(curated.records[0].sourceId,benchmarkGapPersistentSourceId(first));@Expect(benchmarkGapPersistentSourceId(first),benchmarkGapPersistentSourceId(second))
    }

    // T-R0-BND: UTF-8 is preserved and Example is optional but bounded.
    @TestCase public func tR0BndUnicodeOptionalAndOversizedFields():Unit{
        let unicode=p3AtomGap("CJ-UNICODE-001");let accepted=curateBenchmarkGapRecords(p3AtomInputs([unicode]));@Expect(accepted.ok,true);@Expect(accepted.records[0].chunk.contains("中文😀"),true)
        let noExample=p3AtomGap("CJ-NO-EXAMPLE");noExample.knowledgeAtomTestBundle=p3Rehash(p3ValidBundle().replace("ArrayList<Rune> example 中文😀.",""));let noExampleResult=curateBenchmarkGapRecords(p3AtomInputs([noExample]));@Expect(noExampleResult.ok,true);@Expect(noExampleResult.records[0].chunk.endsWith("中文😀."),true);@Expect(noExampleResult.records[0].chunk.contains("Example:"),false)
        let tooLong=p3AtomGap("CJ-LONG-ATOM");tooLong.knowledgeAtomTestBundle=p3Rehash(p3ValidBundle().replace("General ArrayList and Rune usage 中文😀.",p3RepeatAtom("中😀",2049)));@Expect(curateBenchmarkGapRecords(p3AtomInputs([tooLong])).diagnostic,"atom_serving_field_too_long")
    }

    // T-R0-NEG: contamination and compound audit content are checked on the serving projection itself.
    @TestCase public func tR0NegServingMarkersAndCompoundContentFailClosed():Unit{
        for(marker in ["CJ-HUMANEVAL-007","Task: copied prompt","Visible tests: copied","Compiler output: copied","canonical_solution","teacher-solutions","hidden_test","reference solution","solution.cj"]){
            let input=p3AtomGap("CJ-NEG-ATOM");input.knowledgeAtomTestBundle=p3Rehash(p3ValidBundle().replace("General ArrayList and Rune usage 中文😀.",marker));@Expect(curateBenchmarkGapRecords(p3AtomInputs([input])).diagnostic,"atom_content_contamination")
        }
        let compound=p3AtomGap("CJ-COMPOUND-ATOM");compound.knowledgeAtomTestBundle=p3Rehash(p3ValidBundle().replace("General ArrayList and Rune usage 中文😀.","General Rune rule.\nTask: unrelated benchmark recipe."));@Expect(curateBenchmarkGapRecords(p3AtomInputs([compound])).diagnostic,"atom_content_contamination")
    }

    // T-R2-BND: similar but distinct atom identities are not collapsed.
    @TestCase public func tR2BndSimilarButDistinctAtomsRemainSeparate():Unit{
        let first=p3AtomGap("CJ-DISTINCT-001");let second=p3AtomGap("CJ-DISTINCT-002");second.knowledgeAtomTestBundle=p3Rehash(p3ValidBundle().replace("G-ARRAYLIST-RUNE","G-ARRAYLIST-RUNE-COUNT").replace("General ArrayList and Rune usage 中文😀.","General ArrayList Rune count usage 中文😀."))
        let curated=curateBenchmarkGapRecords(p3AtomInputs([first,second]));@Expect(curated.ok,true);@Expect(curated.records.size,2);@Expect(curated.duplicates,0)
    }

    // T-R2-NEG: the same atom identity with divergent serving content fails closed at equal revision.
    @TestCase public func tR2NegDivergentAtomContentConflicts():Unit{
        let first=p3AtomGap("CJ-CONFLICT-001");let second=p3AtomGap("CJ-CONFLICT-002");second.knowledgeAtomTestBundle=p3Rehash(p3ValidBundle().replace("General ArrayList and Rune usage 中文😀.","Different knowledge for the same atom identity."))
        let curated=curateBenchmarkGapRecords(p3AtomInputs([first,second]));@Expect(curated.ok,false);@Expect(curated.accepted,1);@Expect(curated.rejected,1);@Expect(curated.diagnostics[0].contains("benchmark_gap_identity_conflict"),true)
    }
}

func p3BoundaryTest():String{"{\"category\":\"boundary\",\"operation\":\"rune_count\",\"input\":\"中文😀\",\"expected\":\"3\"}"}
func p3ValidBundle():String{p3Rehash("{\"atomId\":\"G-ARRAYLIST-RUNE\",\"sourceClass\":\"official\",\"citation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\",\"targetVersion\":\"1.0.0\",\"candidateHash\":\"sha256:0000000000000000000000000000000000000000000000000000000000000000\",\"knowledgeText\":\"General ArrayList and Rune usage 中文😀.\",\"example\":\"ArrayList<Rune> example 中文😀.\",\"purificationPassed\":true,\"tests\":[{\"category\":\"positive\",\"operation\":\"arraylist_size\",\"input\":\"[1,2,3]\",\"expected\":\"3\"},{\"category\":\"negative\",\"operation\":\"contains\",\"input\":\"ArrayList\",\"needle\":\"HashMap\",\"expected\":\"false\"},${p3BoundaryTest()}]}")}
func p3TeacherEmpiricalBundle():String{p3Rehash("{\"atomId\":\"G-STABLE-DERIVED-KEY-ORDERING\",\"sourceClass\":\"teacher_empirical\",\"citation\":\"\",\"targetVersion\":\"1.0.0\",\"candidateHash\":\"sha256:0000000000000000000000000000000000000000000000000000000000000000\",\"knowledgeFamily\":\"ordering\",\"knowledgeText\":\"Preserve original order when derived keys compare equal.\",\"example\":\"Use a stable insertion step for equal keys.\",\"extractor\":{\"version\":\"extractor-v1\"},\"purificationPassed\":true,\"tests\":[{\"category\":\"positive\",\"operation\":\"arraylist_size\",\"input\":\"[1,2,3]\",\"expected\":\"3\"},{\"category\":\"negative\",\"operation\":\"contains\",\"input\":\"stable\",\"needle\":\"unstable\",\"expected\":\"false\"},${p3BoundaryTest()}],\"teacherEmpiricalProvenance\":{\"originalFailureEvidenceHash\":\"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"completedRunManifestHash\":\"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\",\"solutionBindingHash\":\"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\"},\"execution\":{\"total\":3,\"passed\":3,\"failed\":0,\"status\":\"passed\",\"commandEvidence\":\"positive:ok;negative:ok;boundary:ok\",\"commandEvidenceHash\":\"${benchmarkGapSha256("positive:ok;negative:ok;boundary:ok")}\"}}")}
func p3Rehash(raw:String):String{let marker="sha256:";match(raw.indexOf(marker)){case Some(start)=>let old=raw[start..(start+71)];raw.replace(old,cangjieKnowledgeAtomCandidateHash(raw));case None=>raw}}
func p3CandidateCuration(bundle:String):String{"{\"knowledgeAtomCandidate\" : true,\"knowledgeAtomTestBundle\":${bundle}}\n"}
func p3AtomGap(caseId:String):CangjieBenchmarkGapInput{let input=CangjieBenchmarkGapInput();input.caseId=caseId;input.taskText="audit task";input.compilerOutput="audit compiler output";input.missingKnowledge="G-ARRAYLIST";input.interfaceId="KI-02";input.contentFamily="KC-02";input.updateMechanism="KU-11";input.targetVersion="1.0.0";input.officialCitation="https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection";input.knowledgeAtomCandidate=true;input.knowledgeAtomTestBundle=p3ValidBundle();input}
func p3RepeatAtom(value:String,count:Int64):String{let out=StringBuilder();for(_ in 0..count){out.append(value)};out.toString()}
func p3AtomInputs(values:Array<CangjieBenchmarkGapInput>):ArrayList<CangjieBenchmarkGapInput>{let out=ArrayList<CangjieBenchmarkGapInput>();for(value in values){out.add(value)};out}
