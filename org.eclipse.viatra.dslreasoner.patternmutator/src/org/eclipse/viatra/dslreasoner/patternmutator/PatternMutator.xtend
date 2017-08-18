package org.eclipse.viatra.dslreasoner.patternmutator

import com.google.common.base.Preconditions
import com.google.common.collect.Lists
import com.google.common.collect.Sets
import java.util.ArrayList
import java.util.HashMap
import java.util.HashSet
import java.util.List
import java.util.Set
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EClassifier
import org.eclipse.emf.ecore.EEnum
import org.eclipse.emf.ecore.EEnumLiteral
import org.eclipse.emf.ecore.EPackage
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.emf.ecore.ETypedElement
import org.eclipse.viatra.query.runtime.api.IQuerySpecification
import org.eclipse.viatra.query.runtime.emf.EMFQueryMetaContext
import org.eclipse.viatra.query.runtime.emf.types.EClassTransitiveInstancesKey
import org.eclipse.viatra.query.runtime.emf.types.EStructuralFeatureInstancesKey
import org.eclipse.viatra.query.runtime.exception.ViatraQueryException
import org.eclipse.viatra.query.runtime.matchers.psystem.InitializablePQuery
import org.eclipse.viatra.query.runtime.matchers.psystem.PBody
import org.eclipse.viatra.query.runtime.matchers.psystem.PConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.PVariable
import org.eclipse.viatra.query.runtime.matchers.psystem.annotations.PAnnotation
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.AggregatorConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.Equality
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.ExportedParameter
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.ExpressionEvaluation
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.Inequality
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.NegativePatternCall
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.PatternMatchCounter
import org.eclipse.viatra.query.runtime.matchers.psystem.basicdeferred.TypeFilterConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.BinaryTransitiveClosure
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.ConstantValue
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.PositivePatternCall
import org.eclipse.viatra.query.runtime.matchers.psystem.basicenumerables.TypeConstraint
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.BasePQuery
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PParameter
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PProblem
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.PQuery
import org.eclipse.viatra.query.runtime.matchers.psystem.queries.QueryInitializationException
import org.eclipse.viatra.query.runtime.matchers.psystem.rewriters.PBodyNormalizer
import org.eclipse.viatra.query.runtime.matchers.tuple.FlatTuple
import org.eclipse.viatra.query.runtime.matchers.tuple.Tuples

//import hu.bme.mit.inf.dslreasoner.domains.transima.fam.patterns.Pattern
//import org.eclipse.viatra.query.patternlanguage.patternLanguage.Pattern
public class PatternMutator {
	
	static protected var HashMap<String ,PQuery> outsourcedQueries = newHashMap
		
	new() {}

	
	static class HelperPQuery extends BasePQuery implements InitializablePQuery {

		var String name = "NoName"
		var int version = -1
		//var PAnnotation annotation
		var List<PParameter> parameters = Lists.newArrayList()
		var Set<PBody> bodies = Sets.newLinkedHashSet()

		
		new(){} // Added Bodies Must be initialized later!
		
		new(PQuery queryToCopy) {
			copyPQuery(queryToCopy, null)
			initializeBodies(bodies)
		}
		
		new(PQuery queryToCopy, int version, PConstraint constraintToNegate) {
			this.version = version
			copyPQuery(queryToCopy, constraintToNegate)
			initializeBodies(bodies)
		}
		
		new(PQuery queryToCopy, int version, PParameter parameterToNegate) {
			this.version = version
			copyPQuery(queryToCopy, null)
			initializeBodies(bodies)
		}

		static public def String filterParamWildCards(String parameter) {
			if (parameter.matches("_<[0-9]+>")) {
				return "_"
			}
			return parameter
		}

		def EClassifier getClassifierLiteral(String packageUri,
			String classifierName) throws QueryInitializationException {
			var EPackage ePackage = EPackage.Registry.INSTANCE.getEPackage(packageUri);
			if (ePackage == null)
				throw new QueryInitializationException("Query refers to EPackage {1} not found in EPackage Registry.",
					#{packageUri}, "Query refers to missing EPackage.", this);
			var EClassifier literal = ePackage.getEClassifier(classifierName);
			if (literal == null)
				throw new QueryInitializationException("Query refers to classifier {1} not found in EPackage {2}.",
					#{classifierName, packageUri}, "Query refers to missing type in EPackage.", this);
			return literal;
		}
		
		def EStructuralFeature getFeatureLiteral(String packageUri, String className, String featureName) throws QueryInitializationException {
	       var EClassifier container = getClassifierLiteral(packageUri, className);
	        if (! (container instanceof EClass)) 
	            throw new QueryInitializationException(
	                    "Query refers to EClass {1} in EPackage {2} which turned out not be an EClass.", 
	                    #{className, packageUri}, 
	                    "Query refers to missing EClass.", this);
	        var EStructuralFeature feature = (container as EClass).getEStructuralFeature(featureName);
	        if (feature == null) 
	            throw new QueryInitializationException(
	                    "Query refers to feature {1} not found in EClass {2}.", 
	                    #{featureName, className}, 
	                    "Query refers to missing feature.", this);
	        return feature;
	    }

	    def protected EEnumLiteral getEnumLiteral(String packageUri, String enumName, String literalName) throws QueryInitializationException {
	        var EClassifier enumContainer = getClassifierLiteral(packageUri, enumName);
	        if (! (enumContainer instanceof EEnum)) 
	            throw new QueryInitializationException(
	                    "Query refers to EEnum {1} in EPackage {2} which turned out not be an EEnum.", 
	                    #{enumName, packageUri}, 
	                    "Query refers to missing enumeration type.", this);
	        var EEnumLiteral literal = (enumContainer as EEnum).getEEnumLiteral(literalName);
	        if (literal == null) 
	            throw new QueryInitializationException(
	                    "Query refers to enumeration literal {1} not found in EEnum {2}.", 
	                    #{literalName, enumName}, 
	                    "Query refers to missing enumeration literal.", this);
	        return literal;
	    }
		
		def copyBody(PBody bodyToCopy, PConstraint constraintToNegate) throws QueryInitializationException{
			try {				
				if(!bodies.contains(bodyToCopy)){	
						
					// Create new Body		
					var PBody body = new PBody(this)
					bodies.add(body)
					
					//TODO setSymbolicParameters...
					
					// Copy Constraints
					for (constraint : bodyToCopy.constraints) {
						
						// TypeConstraint
						if (constraint.class == TypeConstraint) {	
							
							// Mutate Selected constraint																		
							if (constraintToNegate != null && constraint.toString == constraintToNegate.toString) {	
																
								var List<PVariable> variables = newArrayList
								for (readVariable : (constraint as TypeConstraint).variablesTuple.elements) {
									var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(readVariable.toString))
									variables.add(variable)
								}	
								for(variable : variables){
									new TypeConstraint(body, Tuples.flatTupleOf(variable),
										new EClassTransitiveInstancesKey(getClassifierLiteral("http://www.eclipse.org/emf/2002/Ecore", "EObject") as EClass))	
								}
																						
								// Derive the name from the constraint	
								var String outsourcedPatternName = ""
								var List<String> nameBuilder = newArrayList
								nameBuilder = bodyToCopy.pattern.fullyQualifiedName.split("\\.")		
								nameBuilder.set(nameBuilder.size-1, "")
								for(element : nameBuilder){
									if(element != "")
									outsourcedPatternName += element + "."
								}
																						
								if((constraint as TypeConstraint).supplierKey.class == EClassTransitiveInstancesKey)
									outsourcedPatternName = ((constraint as TypeConstraint).supplierKey as EClassTransitiveInstancesKey).emfKey.name
								else if((constraint as TypeConstraint).supplierKey.class == EStructuralFeatureInstancesKey)
									outsourcedPatternName += ((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.containerClass.typeName.split("\\.").last + "_" + ( (constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.name.toFirstUpper
								
								// Outsource and create pattern from typeconstraint	
								if(outsourcedPatternName != null && !outsourcedQueries.containsKey(outsourcedPatternName)){
									
									var List<PVariable> outsourcedVariables = newArrayList
									var HelperPQuery pq = new HelperPQuery()
									var PBody outsourcedBody = new PBody(pq) 
									pq.bodies.add(outsourcedBody)
									
									for (readVariable : (constraint as TypeConstraint).variablesTuple.elements) {
											var PVariable variable = outsourcedBody.getOrCreateVariableByName(filterParamWildCards(readVariable.toString))
											outsourcedVariables.add(variable)
									}		
									//Different Key Types
									if((constraint as TypeConstraint).supplierKey.class == EClassTransitiveInstancesKey){
										
										for(variable : outsourcedVariables){
											var PParameter p = new PParameter(variable.name, (((constraint as TypeConstraint).supplierKey as EClassTransitiveInstancesKey).emfKey).name)
											pq.addParameter(p)
										}		
														
										new TypeConstraint(outsourcedBody, Tuples.flatTupleOf(outsourcedVariables.get(0)),
											new EClassTransitiveInstancesKey(((constraint as TypeConstraint).supplierKey as EClassTransitiveInstancesKey).emfKey))
										
									}else if((constraint as TypeConstraint).supplierKey.class == EStructuralFeatureInstancesKey){
										
										for(variable : outsourcedVariables){
											var String typeName
											//find the type name from the parameters
											for(param : bodyToCopy.pattern.parameters){
												if(param.name == variable.name)
													typeName = param.typeName 
											}									
											var PParameter p = new PParameter(variable.name, typeName)
											pq.addParameter(p)
										}		
										
										var String packageUriName =  ((((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey as ETypedElement).EType.EPackage.nsURI.toString)					
										var String className = ((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.containerClass.typeName.split("\\.").last
										var String featureName = ((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.name
										
										new TypeConstraint(outsourcedBody, Tuples.flatTupleOf(outsourcedVariables.toArray), new EStructuralFeatureInstancesKey(
											getFeatureLiteral(packageUriName, className, featureName)))	
									}																				
									pq.name = outsourcedPatternName
									outsourcedQueries.put(pq.name, pq)																																									
									pq.initializeBodies(pq.bodies)
								}
																
								//create negative pattern call on the outsourced pattern
								new NegativePatternCall(body, new FlatTuple(variables.toArray), outsourcedQueries.get(outsourcedPatternName));	

								//remove Parameter Type for mutated queries
								var List<Integer> indexesOfParametersToMutate = newArrayList
					            for (param : parameters) {
					            	var boolean match = false
					            	for (variable : variables) {
						            	if(param.name == variable.name)					            		
											match = true
		            
					            	}
					            	if(match == true){
					            		indexesOfParametersToMutate.add(parameters.indexOf(param))
					            	}
					            }
						        for (index : indexesOfParametersToMutate) {
						        	var p = new PParameter(parameters.get(index).name)
						        	parameters.set(index, p)
						        }

	
							} else {
								if((constraint as TypeConstraint).supplierKey.class == EClassTransitiveInstancesKey){								
									var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(
										(constraint as TypeConstraint).variablesTuple.elements.get(0).toString))
									new TypeConstraint(body, Tuples.flatTupleOf(variable),
										new EClassTransitiveInstancesKey(((constraint as TypeConstraint).supplierKey as EClassTransitiveInstancesKey).emfKey)) 
								}				
								else if((constraint as TypeConstraint).supplierKey.class == EStructuralFeatureInstancesKey){
									var List<PVariable> variables = newArrayList
									for (readVariable : (constraint as TypeConstraint).variablesTuple.elements) {
										var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(readVariable.toString))
										variables.add(variable)
									}						
									var String packageUriName =  ((((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey as ETypedElement).EType.EPackage.nsURI.toString)					
									var String className = ((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.containerClass.typeName.split("\\.").last
									var String featureName = ((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.name
									new TypeConstraint(body, Tuples.flatTupleOf(variables.toArray), new EStructuralFeatureInstancesKey(
												getFeatureLiteral(packageUriName, className, featureName)))	
								}									    
							}
						}
						
						// PositivePatternCall
						if (constraint.class == PositivePatternCall) {
							var List<PVariable> variables = newArrayList
							for (readVariable : (constraint as PositivePatternCall).variablesTuple.elements) {
								var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(readVariable.toString))
								variables.add(variable)
							}				
							if (constraintToNegate != null && constraint.toString == constraintToNegate.toString) {
								new NegativePatternCall(body, new FlatTuple(variables.toArray), (constraint as PositivePatternCall).referredQuery);
							} else {		
					            new PositivePatternCall(body, new FlatTuple(variables.toArray), (constraint as PositivePatternCall).referredQuery);
							}
						}
						
						// NegativePatternCall
						if (constraint.class == NegativePatternCall) {
							var List<PVariable> variables = newArrayList
							for (readVariable : (constraint as NegativePatternCall).actualParametersTuple.elements) {
								var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(readVariable.toString))
								variables.add(variable)
							}
							if (constraintToNegate != null && constraint.toString == constraintToNegate.toString) {
								new PositivePatternCall(body, new FlatTuple(variables.toArray), (constraint as NegativePatternCall).referredQuery);
							} else {		
					            new NegativePatternCall(body, new FlatTuple(variables.toArray), (constraint as NegativePatternCall).referredQuery);
							}							            
						}
						
						// ConstantValue
						if (constraint.class == ConstantValue) {
//			            	TODO: check if supplier is enum before casting...
							var PVariable variable = body.getOrCreateVariableByName(filterParamWildCards(
								(constraint as ConstantValue).variablesTuple.get(0) .toString))
							new ConstantValue(body, variable, (constraint as ConstantValue).supplierKey)									
						}
						
						// Equality
						if (constraint.class == Equality) {
						    var PVariable who = body.getOrCreateVariableByName((constraint as Equality).who.toString)
							var PVariable withWhom = body.getOrCreateVariableByName((constraint as Equality).withWhom.toString)
							if (constraintToNegate != null && constraint.toString == constraintToNegate.toString) {
								new Inequality(body, who, withWhom)	
							} else {		
						    	new Equality(body, who, withWhom)
							}
						}
						
						// Inequality
						if (constraint.class == Inequality) {
							var PVariable who = body.getOrCreateVariableByName((constraint as Inequality).who.toString)
							var PVariable withWhom = body.getOrCreateVariableByName((constraint as Inequality).withWhom.toString)
							if (constraintToNegate != null && constraint.toString == constraintToNegate.toString) {
								new Equality(body, who, withWhom)	
							} else {		
						    	new Inequality(body, who, withWhom)
							}
						}						
					}//ENDFOR					
				}//ENDIF
					
			// to silence compiler error
			if(false) throw new ViatraQueryException("Never", "happens");
			} catch (ViatraQueryException ex) {
					throw (ex);
			}
		}
			
		def copyPQuery(PQuery queryToCopy, PConstraint constraintToCopy) throws QueryInitializationException{
			try {
				
				// Copy Annotations: TODO
				for (annotation : queryToCopy.allAnnotations) {
//					var PAnnotation an = new PAnnotation(annotation.name)
////					for (attribute : annotation.allValues) {
////						an.addAttribute(attribute.key.toString, (attribute.value as Object[]).clone)
////						
////					}
//					this.addAnnotation(an)
				}

				//Copy Name:
				this.name = queryToCopy.fullyQualifiedName.toString
				
				//Copy Parameters:
				for (parameter : queryToCopy.parameters) {
					var PParameter p = new PParameter(parameter.name, parameter.typeName/* , parameter.declaredUnaryType, parameter.direction*/)
					addParameter(p)
				}
				
				// Copy Bodies:	
				var normalizedPquery = new PBodyNormalizer(EMFQueryMetaContext.DEFAULT).rewrite(queryToCopy)				
				for (body : normalizedPquery.bodies) {
					copyBody(body, constraintToCopy)	
				}
				
			// to silence compiler error
			if(false) throw new ViatraQueryException("Never", "happens");
			} catch (ViatraQueryException ex) {
				throw (ex);
			}
		}
		
//			def createBody() throws QueryInitializationException{
//				try { // TODO
//					var PBody body = new PBody(this);
//					// to silence compiler error
//					if(false) throw new ViatraQueryException("Never", "happens");
//				} catch (ViatraQueryException ex) {
//					throw (ex);
//				}
//			}

		def void addParameter(PParameter parameter) {
			this.parameters.add(parameter)
		}
		
		override void addAnnotation(PAnnotation annotation) {
			// Making the upper-level construct visible
			super.addAnnotation(annotation);
		}

		override protected doGetContainedBodies() {
			return bodies
		}

		override getFullyQualifiedName() {
			if (version >= 0) {
				return name + "V" + version
			} else {
				return name
			}			 
		}

		override getParameters() {
			return parameters
		}

		override initializeBodies(Set<PBody> bodies) throws QueryInitializationException {
		    super.bodies = bodies
		}

		override setStatus(PQueryStatus newStatus) {
			Preconditions.checkState(isMutable(),
				"The status of the specification can only be set for uninitialized queries.");
			super.setStatus(newStatus);
		}

		override void addError(PProblem problem) {
			Preconditions.checkState(isMutable() || getStatus().equals(PQueryStatus.ERROR),
				"Errors can only be added to unitialized or erroneous queries.");
			super.addError(problem);
		}
		
	}
	
	static public def String filterParamWildCards(String parameter) {
		if (parameter.matches("_<[0-9]+>")) {
			return "_"
		}
		return parameter
	}
	
	static public def String getTextualRepresentationOfPQuery(PQuery pquery){		
		//TODO explain why it is okay to normalize
		var normalizedPquery = new PBodyNormalizer(EMFQueryMetaContext.DEFAULT).rewrite(pquery)	
		var params = pquery.parameters
//		var patternAnnotation = '''«FOR annotation : pquery.allAnnotations»@«annotation.name»(«FOR value : annotation.allValues SEPARATOR ', '»«IF value.key == "message" || value.key == "severity"»«value.key» = "«value.value»"«ENDIF»«IF value.key == "key"»«value.key» = «value.value»«ENDIF»«ENDFOR»)«ENDFOR»'''
//		var patternAnnotation = '''«FOR annotation : pquery.allAnnotations»@«annotation.name»«ENDFOR»'''	
		var patternName = pquery.fullyQualifiedName.split("\\.").last
		var patternParams ='''(«FOR param : params SEPARATOR ', '»«param.name»«IF param.typeName != null»:«param.typeName.split("\\.").last»«ENDIF»«ENDFOR»)'''		

		var String text = ""				
		text +=	'''
«««		«patternAnnotation»«»
		pattern «patternName»«patternParams» {				
		«FOR body : normalizedPquery.bodies SEPARATOR ' or {'»				
			«FOR constraint : body.constraints»
«««			«constraint.class»
«««			TypeConstraint with EClassTransitiveInstancesKey:
			«IF constraint.class ==  TypeConstraint»
			«IF(constraint as TypeConstraint).supplierKey.class == EClassTransitiveInstancesKey»
			«FOR param : (constraint as TypeConstraint).variablesTuple.elements»
			«((constraint as TypeConstraint).supplierKey as EClassTransitiveInstancesKey).wrappedKey.name»(«filterParamWildCards(param.toString)»);
			«ENDFOR»
			«ENDIF»
«««			TypeConstraint with EStructuralFeatureInstancesKey:
			«IF(constraint as TypeConstraint).supplierKey.class == EStructuralFeatureInstancesKey»
			«((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.containerClass.typeName.split("\\.").last».«
			((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.name»(«
			FOR param : (constraint as TypeConstraint).variablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);		
			«ENDIF»
			«ENDIF»
«««			PositivePatternCall:
			«IF constraint.class == PositivePatternCall»
			find «(constraint as PositivePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
			FOR param : (constraint as PositivePatternCall).getVariablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
			«ENDIF»
«««			NegativePatternCall:
			«IF constraint.class == NegativePatternCall»
			neg find «IF (constraint as NegativePatternCall).referredQuery != null»«(constraint as NegativePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»«ENDIF»(«
			FOR param : (constraint as NegativePatternCall).actualParametersTuple.elements SEPARATOR ', '»«IF param != null»«filterParamWildCards(param.toString)»«ENDIF»«ENDFOR»);	
			«ENDIF»
«««			ConstantValue:
«««         TODO: check if supplier is enum before casting...
			«IF constraint.class == ConstantValue»
			«(constraint as ConstantValue).variablesTuple.get(0)» == «
			(((constraint as ConstantValue).supplierKey)as Enum).declaringClass.name.split("\\.").last»::«
			(constraint as ConstantValue).supplierKey»;
			«ENDIF»
«««			Equality:
			«IF constraint.class == Equality»
			«(constraint as Equality).who» == «(constraint as Equality).withWhom»;
			«ENDIF»
«««			Inequality:
			«IF constraint.class == Inequality»
			«(constraint as Inequality).who» != «(constraint as Inequality).withWhom»;
			«ENDIF»
			«ENDFOR»
		}
		«ENDFOR»	
		'''
		return text
	}
	
	def mutate(List<? extends IQuerySpecification<?>> querySpecifications) {
		
		var specifications = new ArrayList<IQuerySpecification<?>>
		var pQueries = new HashSet<PQuery>
		var HashSet<PQuery> workingSetQueries = new HashSet<PQuery>
		var HashSet<PQuery> mutatedQueries = new HashSet<PQuery>
		
		for (IQuerySpecification<?> specification : querySpecifications) {
			specifications.add(specification);
		}
		
		for (spec : specifications) {
			pQueries.add(spec.internalQueryRepresentation)
		}
	
		for (query : pQueries) {				
			var boolean go = true
			for (annotation : query.allAnnotations) {
				if(annotation.name == "QueryBasedFeature")
					go = false
			}
			if(go){
				workingSetQueries.add(query)
			}
							
		}
		
		for (workingQuery : workingSetQueries) {
			var int cntr = 1;	
			var normalizedPQuery = new PBodyNormalizer(EMFQueryMetaContext.DEFAULT).rewrite(workingQuery)
			println("//_______________________")
			println(getTextualRepresentationOfPQuery(workingQuery))	
			for (body : normalizedPQuery.bodies) {
				for (constraint : body.constraints) {
					if (constraint.class != AggregatorConstraint && constraint.class != ExpressionEvaluation && constraint.class != ExportedParameter && constraint.class != PatternMatchCounter && constraint.class != TypeFilterConstraint && constraint.class != BinaryTransitiveClosure ) {
						var p = new HelperPQuery(workingQuery, cntr, constraint)
						println(getTextualRepresentationOfPQuery(p))
						cntr++						
					}
				}
			}	
		}
		for (mutatedQuery : mutatedQueries) {
			
		}
		
		println("//___________outsourcedQueries:____________")
		
		for (outsourcedQuery: outsourcedQueries.entrySet) {
				println(getTextualRepresentationOfPQuery(outsourcedQuery.value))
		}

					
		for (pquery : pQueries) {

		}

//«««						«patternAnnotation»«»
//							pattern «patternName»V«cntr»«patternParams» {				
//							«FOR body : normalizedPquery.bodies SEPARATOR ' or {'»				
//								«FOR constraint : body.constraints»
//«««									«constraint.class»
//«««									TypeConstraint with EClassTransitiveInstancesKey:
//								«IF constraint.class ==  TypeConstraint»
//								«IF constraint  != outsideConstraint»
//								«IF(constraint as TypeConstraint).supplierKey.class == EClassTransitiveInstancesKey»
//								«FOR param : (constraint as TypeConstraint).variablesTuple.elements»
//								«((constraint as TypeConstraint).supplierKey as EClassTransitiveInstancesKey).wrappedKey.name»(«filterParamWildCards(param.toString)»);
//								«ENDFOR»	
//								«ENDIF»															
//								«IF constraint  == outsideConstraint»
//								«ENDIF»
//								«ENDIF»
//«««									TypeConstraint with EStructuralFeatureInstancesKey:
//								«IF(constraint as TypeConstraint).supplierKey.class == EStructuralFeatureInstancesKey»
//								«((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.containerClass.typeName.split("\\.").last».«
//								((constraint as TypeConstraint).supplierKey as EStructuralFeatureInstancesKey).wrappedKey.name»(«
//								FOR param : (constraint as TypeConstraint).variablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);		
//								«ENDIF»
//								«ENDIF»
//«««									PositivePatternCall:
//								«IF constraint.class == PositivePatternCall»
//								«IF outsideConstraint != constraint»
//								find «(constraint as PositivePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
//								FOR param : (constraint as PositivePatternCall).getVariablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
//								«ENDIF»
//								«IF outsideConstraint == constraint»
//								neg find «(constraint as PositivePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
//								FOR param : (constraint as PositivePatternCall).getVariablesTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);
//								«ENDIF»
//								«ENDIF»
//«««									NegativePatternCall:
//								«IF constraint.class == NegativePatternCall»
//								«IF outsideConstraint != constraint»
//								neg find «(constraint as NegativePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
//								FOR param : (constraint as NegativePatternCall).actualParametersTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
//								«ENDIF»
//								«IF outsideConstraint == constraint»
//								find «(constraint as NegativePatternCall).referredQuery.fullyQualifiedName.split("\\.").last»(«
//								FOR param : (constraint as NegativePatternCall).actualParametersTuple.elements SEPARATOR ', '»«filterParamWildCards(param.toString)»«ENDFOR»);	
//								«ENDIF»
//								«ENDIF»
//«««									ConstantValue:
//«««					            	TODO: check if supplier is enum before casting...
//								«IF constraint.class == ConstantValue»
//								«IF outsideConstraint != constraint»
//								«(constraint as ConstantValue).variablesTuple.get(0)» == «
//								(((constraint as ConstantValue).supplierKey)as Enum).declaringClass.name.split("\\.").last»::«
//								(constraint as ConstantValue).supplierKey»;
//								«ENDIF»									
//								«IF outsideConstraint == constraint»
//								«(constraint as ConstantValue).variablesTuple.get(0)» != «
//								(((constraint as ConstantValue).supplierKey)as Enum).declaringClass.name.split("\\.").last»::«
//								(constraint as ConstantValue).supplierKey»;
//								«ENDIF»
//								«ENDIF»
//«««									Equality:
//								«IF constraint.class == Equality»
//								«IF outsideConstraint != constraint»
//								«(constraint as Equality).who» == «(constraint as Equality).withWhom»;
//								«ENDIF»
//								«IF outsideConstraint == constraint»«(constraint as Equality).who» != «(constraint as Equality).withWhom»;
//								«ENDIF»
//								«ENDIF»
//«««									Inequality:
//								«IF constraint.class == Inequality»
//								«IF outsideConstraint != constraint»
//								«(constraint as Inequality).who» != «(constraint as Inequality).withWhom»;
//								«ENDIF»
//								«IF outsideConstraint == constraint»
//								«(constraint as Inequality).who» == «(constraint as Inequality).withWhom»;
//								«ENDIF»
//								«ENDIF»
//								«ENDFOR»
//							}
//							«ENDFOR»
//							
//							'''					
	}

}

	