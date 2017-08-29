package cpsgen

import hu.bme.mit.inf.dslreasoner.ecore2logic.Ecore2Logic
import hu.bme.mit.inf.dslreasoner.ecore2logic.Ecore2LogicConfiguration
import hu.bme.mit.inf.dslreasoner.ecore2logic.EcoreMetamodelDescriptor
import hu.bme.mit.inf.dslreasoner.logic.model.builder.LogicReasoner
import hu.bme.mit.inf.dslreasoner.logic.model.logicresult.LogicResult
import hu.bme.mit.inf.dslreasoner.logic.model.logicresult.ModelResult
import hu.bme.mit.inf.dslreasoner.logic2ecore.Logic2Ecore
import hu.bme.mit.inf.dslreasoner.viatra2logic.Viatra2Logic
import hu.bme.mit.inf.dslreasoner.viatra2logic.Viatra2LogicConfiguration
import hu.bme.mit.inf.dslreasoner.viatra2logic.ViatraQuerySetDescriptor
import hu.bme.mit.inf.dslreasoner.viatrasolver.partialinterpretation2logic.InstanceModel2Logic
import hu.bme.mit.inf.dslreasoner.viatrasolver.partialinterpretationlanguage.partialinterpretation.PartialInterpretation
import hu.bme.mit.inf.dslreasoner.viatrasolver.partialinterpretationlanguage.visualisation.PartialInterpretation2Gml
import hu.bme.mit.inf.dslreasoner.viatrasolver.reasoner.ViatraReasoner
import hu.bme.mit.inf.dslreasoner.viatrasolver.reasoner.ViatraReasonerConfiguration
import hu.bme.mit.inf.dslreasoner.workspace.FileSystemWorkspace
import java.util.HashMap
import java.util.HashSet
import java.util.LinkedHashMap
import java.util.LinkedList
import java.util.List
import java.util.Set
import mutatedpatterns.AppTypeInstanceAndHost1
import mutatedpatterns.AppTypeInstanceAndHost2
import mutatedpatterns.HostCommunication1
import mutatedpatterns.MultipleApplicationInstanceInCommunicationGroup1
import mutatedpatterns.MultipleApplicationInstanceInCommunicationGroup2
import mutatedpatterns.MultipleApplicationInstanceInCommunicationGroup3
import mutatedpatterns.OutsourcedQueries
import mutatedpatterns.Pattern
import mutatedpatterns.ReachableAppInstance1
import mutatedpatterns.ReachableAppInstance2
import mutatedpatterns.StateTransition1
import mutatedpatterns.StateTransition2
import mutatedpatterns.StateTransition3
import mutatedpatterns.TargetStateNotContainedBySameStateMachine1
import mutatedpatterns.TargetStateNotContainedBySameStateMachine2
import mutatedpatterns.TargetStateNotContainedBySameStateMachine3
import mutatedpatterns.TransitionWithoutTargetState1
import mutatedpatterns.TransitionWithoutTargetState2
import org.eclipse.emf.ecore.EAttribute
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EEnum
import org.eclipse.emf.ecore.EEnumLiteral
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EPackage
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl
import org.eclipse.viatra.examples.cps.cyberPhysicalSystem.CyberPhysicalSystemPackage
import org.eclipse.viatra.query.runtime.api.IQuerySpecification
import org.eclipse.viatra.query.runtime.emf.types.BaseEMFTypeKey
import org.eclipse.viatra.query.runtime.emf.types.EClassTransitiveInstancesKey
import org.eclipse.viatra.query.runtime.emf.types.EClassUnscopedTransitiveInstancesKey

class Run {
	
     /**
     *  Initializes the files needed for the generate method. Iterates over all the query specifications contained by <b>queriesToGenerateFrom</b> 
     *  and calls the generate method for each ViatraQuerySetDescriptor.
     */
    def static void main(String[] args) {
        val initialModelsLocation = new FileSystemWorkspace('''initialModels/''',"")
        val outputModelsLocation = new FileSystemWorkspace('''outputModels/''',"")
        outputModelsLocation.initAndClear      
        println("Input and output workspaces are created")        
        val EcoreMetamodelDescriptor metamodel = loadMetamodel(CyberPhysicalSystemPackage.eINSTANCE)
        val List<EObject> initialModel = Run.loadInitialModel(initialModelsLocation, "cps.xmi")       
        val HashMap<String, ViatraQuerySetDescriptor> queriesToGenerateFrom = new HashMap<String, ViatraQuerySetDescriptor>  
        //Set of the base pattern specifications and outsourced pattern specifications, to be referred by the mutated patterns.
      	val baseSpecifications = (Pattern.instance.specifications + OutsourcedQueries.instance.specifications).toSet  	
       	//TODO AutoLoad:   
		queriesToGenerateFrom.put("AppTypeInstanceAndHost1", loadQueries(metamodel, baseSpecifications, AppTypeInstanceAndHost1.instance.specifications))
		queriesToGenerateFrom.put("AppTypeInstanceAndHost2", loadQueries(metamodel, baseSpecifications, AppTypeInstanceAndHost2.instance.specifications))
		queriesToGenerateFrom.put("HostCommunication1", loadQueries(metamodel, baseSpecifications, HostCommunication1.instance.specifications))
		queriesToGenerateFrom.put("MultipleApplicationInstanceInCommunicationGroup1", loadQueries(metamodel, baseSpecifications, MultipleApplicationInstanceInCommunicationGroup1.instance.specifications))
		queriesToGenerateFrom.put("MultipleApplicationInstanceInCommunicationGroup2", loadQueries(metamodel, baseSpecifications, MultipleApplicationInstanceInCommunicationGroup2.instance.specifications))
		queriesToGenerateFrom.put("MultipleApplicationInstanceInCommunicationGroup3", loadQueries(metamodel, baseSpecifications, MultipleApplicationInstanceInCommunicationGroup3.instance.specifications))
		queriesToGenerateFrom.put("ReachableAppInstance1", loadQueries(metamodel, baseSpecifications, ReachableAppInstance1.instance.specifications))
		queriesToGenerateFrom.put("ReachableAppInstance2", loadQueries(metamodel, baseSpecifications, ReachableAppInstance2.instance.specifications))
		queriesToGenerateFrom.put("StateTransition1", loadQueries(metamodel, baseSpecifications, StateTransition1.instance.specifications))
		queriesToGenerateFrom.put("StateTransition2", loadQueries(metamodel, baseSpecifications, StateTransition2.instance.specifications))
		queriesToGenerateFrom.put("StateTransition3", loadQueries(metamodel, baseSpecifications, StateTransition3.instance.specifications))
		queriesToGenerateFrom.put("TargetStateNotContainedBySameStateMachine1", loadQueries(metamodel, baseSpecifications, TargetStateNotContainedBySameStateMachine1.instance.specifications))
		queriesToGenerateFrom.put("TargetStateNotContainedBySameStateMachine2", loadQueries(metamodel, baseSpecifications, TargetStateNotContainedBySameStateMachine2.instance.specifications))
		queriesToGenerateFrom.put("TargetStateNotContainedBySameStateMachine3", loadQueries(metamodel, baseSpecifications, TargetStateNotContainedBySameStateMachine3.instance.specifications))		
		queriesToGenerateFrom.put("TransitionWithoutTargetState1", loadQueries(metamodel, baseSpecifications, TransitionWithoutTargetState1.instance.specifications))
		queriesToGenerateFrom.put("TransitionWithoutTargetState2", loadQueries(metamodel, baseSpecifications, TransitionWithoutTargetState2.instance.specifications))
	  	println("DSL loaded")     	
		for(descriptorKey : queriesToGenerateFrom.keySet){						      
			val descriptor = queriesToGenerateFrom.get(descriptorKey)			
			val viatraConfig = new ViatraReasonerConfiguration => [
	            it.typeScopes.maxNewElements = 40
	            it.typeScopes.minNewElements = 40
	            it.solutionScope.numberOfRequiredSolution = 1
	            it.existingQueries = descriptor.patterns.map[it.internalQueryRepresentation]
	            it.debugCongiguration.logging = false
	            //it.debugCongiguration.partalInterpretationVisualisationFrequency = 1
	            //it.debugCongiguration.partialInterpretatioVisualiser = new GraphvizVisualisation
		    ]
		    println("____________________________")
	    	println("Specifications to generate from: " + '"' + descriptorKey + '"')
		    generate(viatraConfig, descriptorKey, descriptor, metamodel, initialModel, outputModelsLocation)
		}//ENDFOR
    }
    
    /** 
     * Generates an instance model from the provided configuration, patterns, metamodel, and initial model. 
     * The generated instance model is saved in outputModelsLocation as "saveName".xmi. A "saveName"_solutionVisualisation.gml file 
     * and other helper files are also saved in the same folder. The .gml is useable by yEd Graph Editor.
     * @param viatraConfig ViatraReasonerConfiguration 
     * @param saveName The generated instance model is saved in outputModelsLocation as saveName.
     * @param queryToGenerateFrom ViatraQuerySetDescriptor describing the used patterns. 
     * @param metamodel The metamodel for which we generate instances.
     * @param initialModels List of the initial models, to use as base for the generation. 
     * @param outputModelsLocation FileSystemWorkspace describing the location where the generated models are going to be saved.
     * 
     */
    def private static void generate(
    	ViatraReasonerConfiguration viatraConfig,
    	String saveName,
    	ViatraQuerySetDescriptor queryToGenerateFrom, 
    	EcoreMetamodelDescriptor metamodel, 
    	List<EObject> initialModel, 
    	FileSystemWorkspace outputModelsLocation
    ){
        val Ecore2Logic ecore2Logic = new Ecore2Logic
        val Logic2Ecore logic2Ecore = new Logic2Ecore(ecore2Logic)
        val Viatra2Logic viatra2Logic = new Viatra2Logic(ecore2Logic)
        val InstanceModel2Logic instanceModel2Logic = new InstanceModel2Logic        
        val modelGenerationProblem = ecore2Logic.transformMetamodel(metamodel, new Ecore2LogicConfiguration())
        val modelExtensionProblem = instanceModel2Logic.transform(modelGenerationProblem, initialModel)
        val validModelExtensionProblem = viatra2Logic.transformQueries(queryToGenerateFrom, modelGenerationProblem, new Viatra2LogicConfiguration)       
        val logicProblem = validModelExtensionProblem.output        
        println("Problem created for " + '"' + saveName + '"')
        var LogicResult solution
        var LogicReasoner reasoner
        reasoner = new ViatraReasoner
        solution = reasoner.solve(logicProblem, viatraConfig, outputModelsLocation)       
        println("Problem solved for " + '"' + saveName + '"')
        val interpretations = reasoner.getInterpretations(solution as ModelResult)
        val models = new LinkedList
        for(interpretation : interpretations) {
            val instanceModel = logic2Ecore.transformInterpretation(interpretation,modelGenerationProblem.trace)
            models+=instanceModel
        }
        solution.writeSolution(outputModelsLocation, models, saveName)          
    }
    
    /**
     * Creates an EcoreMetamodelDescriptor as the metamodel to be used by the generator.
     */
    def private static EcoreMetamodelDescriptor loadMetamodel(EPackage pckg) {
        val List<EClass> classes = pckg.EClassifiers.filter(EClass).toList
        val List<EEnum> enums = pckg.EClassifiers.filter(EEnum).toList
        val List<EEnumLiteral> literals = enums.map[ELiterals].flatten.toList
        val List<EReference> references = classes.map[EReferences].flatten.toList
        val List<EAttribute> attributes = emptyList//classes.map[EAttributes].flatten.toList
        return new EcoreMetamodelDescriptor(classes,#{},false,enums,literals,references, attributes)
    }
    
    /**
     * Creates a <b>ViatraQuerySetDescriptor</b> from the provided metamodel, baseSpecifications and specifications.
     * Well-formedness patterns must be marked with the <b>@Constraint</b> annotation.
     * All the patterns referred by the <b>specifications</b> must be included in <b>baseSpecifications</b>. The non referred queries are filtered automatically.
     * 
     * @param metamodel 
     * @param baseSpecifications 
     * @param specifications
     */
    def private static ViatraQuerySetDescriptor loadQueries(EcoreMetamodelDescriptor metamodel, Set<IQuerySpecification<?>> baseSpecifications, Set<IQuerySpecification<?>> specifications) { 
        val patterns = new HashSet<IQuerySpecification<?>>
        val wfPatterns = patterns.filter[it.allAnnotations.exists[it.name== "Constraint"]].toSet   
        for (pattern : specifications.toList) {
        	//Add EClass keys defined in patterns: 
        	for(parameter : pattern.parameters){
        		val uType = parameter.declaredUnaryType
        		if(uType.class == BaseEMFTypeKey){
        			val emfkey = (uType as BaseEMFTypeKey<?>).emfKey
	        		if(emfkey.class == EClassTransitiveInstancesKey || emfkey.class == EClassUnscopedTransitiveInstancesKey)
	        		 {
	        			println((parameter.declaredUnaryType as BaseEMFTypeKey<?>).emfKey)
	        			val emfKey = ((uType as BaseEMFTypeKey<?>).emfKey as EClass)
			        	if(!metamodel.classes.contains(emfKey)){
		        			metamodel.classes.add(emfKey)
		        		}		
	        		}
        		}
        	}
        	//Get referredQueries
        	for(referredPQuery: pattern.internalQueryRepresentation.allReferredQueries){
        		patterns.addAll(baseSpecifications.filter[it.fullyQualifiedName == referredPQuery.fullyQualifiedName])
        	}      
        }    
        val res = new ViatraQuerySetDescriptor(
            patterns.toList,
            wfPatterns,
            new LinkedHashMap  
        )
        return res
    }
    
    /**
     * Loads the initial model and registers the resource.
     */
    def static List<EObject> loadInitialModel(FileSystemWorkspace location, String fileName) {
        Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("*", new XMIResourceFactoryImpl());
        return location.readModel(EObject, fileName).eResource.allContents.toList
    }
    
    /**
     * 
     */
    def static writeSolution(LogicResult solution, FileSystemWorkspace location, List<EObject> models, String name) {
        if(solution instanceof ModelResult) {
            val representations = solution.representation
            for(representationIndex : 0..<representations.size) {
                val representation = representations.get(representationIndex)
                val representationNumber = representationIndex + 1
                if(representation instanceof PartialInterpretation) {
                    location.writeModel(representation, name + '''_solution«representationNumber».partialinterpretation''')
                    val partialInterpretation2GML = new PartialInterpretation2Gml
                    val gml = partialInterpretation2GML.transform(representation)
                        //ecore2GML.transform(root)
                        location.writeText(name + '''_solutionVisualisation.gml''',gml)                        
                } else {
                    location.writeText(name + '''_solution«representationNumber».txt''',representation.toString)
                }
            }
            for(model : models) {
                location.writeModel(model,name + ".xmi")
            }
            println("Solution saved and visualised for " + '"' + name + '"')
        } 
    }
}