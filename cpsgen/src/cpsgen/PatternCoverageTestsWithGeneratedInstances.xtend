package cpsgen

import com.google.common.collect.Sets
import cpsgen.patterns.util.CircularDependencyInAppsQuerySpecification
import java.io.File
import java.util.Collection
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.viatra.query.runtime.api.AdvancedViatraQueryEngine
import org.eclipse.viatra.query.runtime.api.IPatternMatch
import org.eclipse.viatra.query.runtime.api.IQuerySpecification
import org.eclipse.viatra.query.runtime.api.ViatraQueryMatcher
import org.eclipse.viatra.query.runtime.emf.EMFScope
import org.eclipse.viatra.query.testing.core.XmiModelUtil
import org.eclipse.viatra.query.testing.core.XmiModelUtil.XmiModelUtilRunningOptionEnum
import org.eclipse.viatra.query.testing.core.coverage.CoverageAnalyzer
import org.eclipse.viatra.query.testing.core.coverage.CoverageReporter
import org.junit.AfterClass
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import org.junit.runners.Parameterized.Parameter
import org.junit.runners.Parameterized.Parameters
import org.eclipse.viatra.query.testing.core.api.ViatraQueryTest
import org.eclipse.emf.common.util.URI

@RunWith(Parameterized)
class PatternCoverageTestsWithGeneratedInstances {
    static var CoverageAnalyzer coverage;

    @Parameters(name="Model: {0}, Query: {1}")
    def static Collection<Object[]> testData() {
        newArrayList(Sets.cartesianProduct(
            #{"cpsgen/outputModels/model.xmi"}, // models to use for testing queries
            #{CircularDependencyInAppsQuerySpecification.instance} // queries to test
        ).map[it.toArray])
    }

    @Parameter(0)
    public String modelPath
    @Parameter(1)
    public IQuerySpecification query

    ResourceSet rs
    URI modelUri
    
    @BeforeClass
    static def void beforeClass() {
        coverage = new CoverageAnalyzer();
    }
    

    @Before
    def void before() {
        modelUri = XmiModelUtil::resolvePlatformURI(XmiModelUtilRunningOptionEnum.BOTH, modelPath)
        rs = new ResourceSetImpl
        rs.getResource(modelUri, true)
    }

    @AfterClass
    static def void after() {
        CoverageReporter.reportHtml(coverage, new File("coverage.html"))
    }

    @Test
    def void patternCoverage() {

        val AdvancedViatraQueryEngine engine = AdvancedViatraQueryEngine.createUnmanagedEngine(new EMFScope(rs));
        val hint = coverage.configure(engine.engineOptions.engineDefaultHints)
        
        val ViatraQueryMatcher<? extends IPatternMatch> matcher = engine.getMatcher(query, hint);
        val Collection<? extends IPatternMatch> matches = matcher.getAllMatches();
        println(matches)

        coverage.processMatcher(matcher)
        ViatraQueryTest.test(query)
        .analyzeWith(coverage)
//        .on(modelUri)
//        .assertEquals
   
    }
}
