package cpsgen

import com.google.common.collect.Sets
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
import mutatedpatterns.util.TransitionWithoutTargetStateQuerySpecification
import mutatedpatterns.util.StateTransitionQuerySpecification
import mutatedpatterns.util.TargetStateNotContainedBySameStateMachineQuerySpecification
import mutatedpatterns.util.MultipleApplicationInstanceInCommunicationGroupQuerySpecification
import mutatedpatterns.util.AppTypeInstanceAndHostQuerySpecification
import mutatedpatterns.util.HostCommunicationQuerySpecification
import mutatedpatterns.util.ReachableHostsQuerySpecification
import mutatedpatterns.util.ReachableAppInstanceQuerySpecification
@RunWith(Parameterized)
class PatternCoverageTestsWithGeneratedInstances {
    static var CoverageAnalyzer coverage;

    @Parameters(name="Model: {0}, Query: {1}")
    def static Collection<Object[]> testData() {
        newArrayList(Sets.cartesianProduct(
            #{// models to use for testing queries
            "cpsgen/saved_models/model_original.xmi",
            "cpsgen/outputModels/AppTypeInstanceAndHost1.xmi", 
            "cpsgen/outputModels/AppTypeInstanceAndHost2.xmi", 
            "cpsgen/outputModels/HostCommunication1.xmi",
            "cpsgen/outputModels/MultipleApplicationInstanceInCommunicationGroup1.xmi",
            "cpsgen/outputModels/MultipleApplicationInstanceInCommunicationGroup2.xmi",
            "cpsgen/outputModels/MultipleApplicationInstanceInCommunicationGroup3.xmi",
            "cpsgen/outputModels/ReachableAppInstance1.xmi",
            "cpsgen/outputModels/ReachableAppInstance2.xmi",
            "cpsgen/outputModels/StateTransition1.xmi",
            "cpsgen/outputModels/StateTransition2.xmi",
            "cpsgen/outputModels/StateTransition3.xmi",
            "cpsgen/outputModels/TargetStateNotContainedBySameStateMachine1.xmi",
            "cpsgen/outputModels/TargetStateNotContainedBySameStateMachine2.xmi",
            "cpsgen/outputModels/TargetStateNotContainedBySameStateMachine3.xmi",
            "cpsgen/outputModels/TransitionWithoutTargetState1.xmi",
            "cpsgen/outputModels/TransitionWithoutTargetState2.xmi"
            }, 
            #{ // queries to test
            	TransitionWithoutTargetStateQuerySpecification.instance,
            	StateTransitionQuerySpecification.instance,
            	TargetStateNotContainedBySameStateMachineQuerySpecification.instance,
            	MultipleApplicationInstanceInCommunicationGroupQuerySpecification.instance,
            	AppTypeInstanceAndHostQuerySpecification.instance,
            	HostCommunicationQuerySpecification.instance,
            	ReachableHostsQuerySpecification.instance,
            	ReachableAppInstanceQuerySpecification.instance
            }
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
    }
}
