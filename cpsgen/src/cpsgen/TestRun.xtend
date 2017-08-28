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
import hu.bme.mit.inf.dslreasoner.workspace.ReasonerWorkspace
import java.util.HashMap
import java.util.HashSet
import java.util.LinkedHashMap
import java.util.LinkedList
import java.util.List
import java.util.Set
import mutatedpatterns.Pattern
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
import org.eclipse.emf.ecore.EcoreFactory
import org.eclipse.emf.ecore.EcorePackage

class TestRun {
    
    def static void main(String[] args) {
        val inputs = new FileSystemWorkspace('''initialModels/''',"")
        val workspace = new FileSystemWorkspace('''outputModels/''',"")
        workspace.initAndClear
        
        println("Input and output workspaces are created")
        
        // Loading metamodel produces java.lang.UnsupportedOperationException: Unsupported attribute type: EString
        val metamodel = loadMetamodel(CyberPhysicalSystemPackage.eINSTANCE)
        val partialModel = loadPartialModel(inputs)       
        val  HashMap<String, ViatraQuerySetDescriptor> queries = new HashMap<String, ViatraQuerySetDescriptor>
        
       	
       	queries.put("Base", loadQueries(metamodel, new HashSet<IQuerySpecification<?>>, Pattern.instance.specifications))

		
        for(descriptorKey : queries.keySet){
        	println("____________________________")
	        println("DSL loaded for " + '"' + descriptorKey + '"')
	        val descriptor = queries.get(descriptorKey)
	        val Ecore2Logic ecore2Logic = new Ecore2Logic
	        val Logic2Ecore logic2Ecore = new Logic2Ecore(ecore2Logic)
	        val Viatra2Logic viatra2Logic = new Viatra2Logic(ecore2Logic)
	        val InstanceModel2Logic instanceModel2Logic = new InstanceModel2Logic        
	        val modelGenerationProblem = ecore2Logic.transformMetamodel(metamodel,new Ecore2LogicConfiguration())
	        val modelExtensionProblem = instanceModel2Logic.transform(modelGenerationProblem,partialModel)
	        val validModelExtensionProblem = viatra2Logic.transformQueries(descriptor, modelGenerationProblem, new Viatra2LogicConfiguration)
	        
	        val logicProblem = validModelExtensionProblem.output
	        
	        println("Problem created")
	        var LogicResult solution
	        var LogicReasoner reasoner
	        reasoner = new ViatraReasoner
	        val viatraConfig = new ViatraReasonerConfiguration => [
	            it.typeScopes.maxNewElements = 40
	            it.typeScopes.minNewElements = 40
	            it.solutionScope.numberOfRequiredSolution = 1
	            it.existingQueries = descriptor.patterns.map[it.internalQueryRepresentation]
	            it.debugCongiguration.logging = false
	            //it.debugCongiguration.partalInterpretationVisualisationFrequency = 1
	            //it.debugCongiguration.partialInterpretatioVisualiser = new GraphvizVisualisation
	        ]
	        solution = reasoner.solve(logicProblem,viatraConfig,workspace)
	        println("Problem solved")
	        val interpretations = reasoner.getInterpretations(solution as ModelResult)
	        val models = new LinkedList
	        for(interpretation : interpretations) {
	            val instanceModel = logic2Ecore.transformInterpretation(interpretation,modelGenerationProblem.trace)
	            models+=instanceModel
	        }
	        solution.writeSolution(workspace, models, descriptorKey)
        }     
    }
    
    def private static loadMetamodel(EPackage pckg) {
        val List<EClass> classes = pckg.EClassifiers.filter(EClass).toList
        val List<EEnum> enums = pckg.EClassifiers.filter(EEnum).toList
        val List<EEnumLiteral> literals = enums.map[ELiterals].flatten.toList
        val List<EReference> references = classes.map[EReferences].flatten.toList
        val List<EAttribute> attributes = classes.map[EAttributes].flatten.toList
        return new EcoreMetamodelDescriptor(classes,#{},false,enums,literals,references, attributes)
    }
    
    def private static loadQueries(EcoreMetamodelDescriptor metamodel, Set<IQuerySpecification<?>> baseSpecifications, Set<IQuerySpecification<?>> specifications) { 
        val patterns = new HashSet<IQuerySpecification<?>>
        val wfPatterns = patterns.filter[it.allAnnotations.exists[it.name== "Constraint"]].toSet
        val derivedFeatures = new LinkedHashMap       
        for (pattern : specifications.toList) {
        	//Add EClasses defined in patterns: 
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

       // patterns.addAll(baseSpecifications.filter[it.fullyQualifiedName == ])
        //derivedFeatures.put(i.type.internalQueryRepresentation,metamodel.attributes.filter[it.name == "type"].head)
        //derivedFeatures.put(i.model.internalQueryRepresentation,metamodel.references.filter[it.name == "model"].head)
        val res = new ViatraQuerySetDescriptor(
            patterns.toList,
            wfPatterns,
            derivedFeatures
        )
        return res
    }
    
    def static loadPartialModel(ReasonerWorkspace inputs) {
        Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("*", new XMIResourceFactoryImpl());
               // println(inputs.readModel(EObject,"cps.xmi")/* .eResource.allContents.toList*/)
        inputs.readModel(EObject,"cps.xmi").eResource.allContents.toList
    }
    
    def static writeSolution(LogicResult solution, ReasonerWorkspace workspace, List<EObject> models, String name) {
        if(solution instanceof ModelResult) {
            val representations = solution.representation
            for(representationIndex : 0..<representations.size) {
                val representation = representations.get(representationIndex)
                val representationNumber = representationIndex + 1
                if(representation instanceof PartialInterpretation) {
                    workspace.writeModel(representation, name + '''solution«representationNumber».partialinterpretation''')
                    val partialInterpretation2GML = new PartialInterpretation2Gml
                    val gml = partialInterpretation2GML.transform(representation)
                        //ecore2GML.transform(root)
                        workspace.writeText(name + '''solutionVisualisation.gml''',gml)
                        
                } else {
                    workspace.writeText(name + '''solution«representationNumber».txt''',representation.toString)
                }
            }
            for(model : models) {
                workspace.writeModel(model,name + ".xmi")
            }
            println("Solution saved and visualised for " + '"' + name + '"')
        } 
    }
}