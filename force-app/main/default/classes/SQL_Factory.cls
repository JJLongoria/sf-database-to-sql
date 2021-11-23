public class SQL_Factory {

    private class ObjectWrapper{
        public String apiName { get; set; }
        public List<String> referencedFields { get; set; }
        public Map<String, FieldWrapper> fields { get; set; }
    }
    
    private class FieldWrapper { 
        public String apiName { get; set; }
        public String referencedObjectApiName { get; set; }
        public String relationshipName { get; set; }
    }

    private static Map<String, String> getDataTypes(){
        Map<String, String> dataTypes = new Map<String, String>();
        dataTypes.put('combobox', 'BOOLEAN');
        dataTypes.put('currency', 'DOUBLE');
        dataTypes.put('email', 'VARCHAR(255)');
        dataTypes.put('id', 'CHAR(18)');
        dataTypes.put('multipicklist', 'VARCHAR(1000)');
        dataTypes.put('percent', 'DOUBLE');
        dataTypes.put('phone', 'VARCHAR(100)');
        dataTypes.put('picklist', 'VARCHAR(255)');
        dataTypes.put('reference', 'CHAR(18)');
        dataTypes.put('textarea', 'TEXT');
        dataTypes.put('url', 'VARCHAR(255)');
        dataTypes.put('boolean', 'BOOLEAN');
        dataTypes.put('string', 'TEXT');
        dataTypes.put('double', 'DOUBLE');
        dataTypes.put('date', 'DATE');
        dataTypes.put('datetime', 'DATETIME');
        dataTypes.put('time', 'TIME');
        dataTypes.put('address', 'TIME');
        return dataTypes;
    }
    
    public static String toSQL(List<String> sObjectList){
        Map<String, ObjectWrapper> sObjectWithReferences = getSobjectWithReferencesMap(sObjectList);
        List<String> objectsInOrderToCreate = getObjectInOrderToCreate(sObjectWithReferences);
        List<String> objectScript = new List<String>();
        for(String objectToCreateScript : objectsInOrderToCreate){
            if(objectToCreateScript != null && !String.isEmpty(objectToCreateScript) && sObjectWithReferences.get(objectToCreateScript) != null){
             	objectScript.add(getObjectScript(sObjectWithReferences.get(objectToCreateScript), sObjectList));   
            }
        }
        String script = String.join(objectScript, '\n');
        return script;
    }
    
    private static String getObjectScript(ObjectWrapper obj, List<String> sObjectList){
        String script = 'Create Table IF NOT EXISTS ' + obj.apiName + ' (\n';
        Integer cont = 0;
        for(FieldWrapper field : obj.fields.values()){
            script += getFieldDefinition(field, obj.apiName, (obj.fields.size() -1) == cont, sObjectList);
            cont++;
        }
        script += ');\n';
        return script;
    }
    
    private static String getFieldDefinition(FieldWrapper field, String obNamej, boolean isLast, List<String> sObjectList){
        system.debug('@@field => ' + field);
        system.debug('@@obNamej => ' + obNamej);
        Map<String, String> dataTypes = getDataTypes();
        Schema.SObjectField objField = Schema.getGlobalDescribe().get(obNamej).getDescribe().fields.getMap().get(field.apiName.toLowerCase());
        String fieldType = String.valueOf(objField.getDescribe().getType()).toLowerCase();
        String dataType = dataTypes.get(fieldType);
        String fieldDefinition = '';
        if(objField.getDescribe().isAutoNumber()){
            fieldDefinition += field.apiName + ' INTEGER';
        }
        else if(field.apiName.toLowerCase() == 'id'){
            fieldDefinition += field.apiName + ' ' + dataType + ' PRIMARY KEY';
        }
        else if(fieldType == 'reference'){
            fieldDefinition += field.apiName + ' ' + dataType + '';
            if(field.relationshipName != null && field.referencedObjectApiName != null)
            	fieldDefinition += ',\nFOREIGN KEY ('+field.apiName+') REFERENCES '+field.referencedObjectApiName+' (Id)';
        }
        else{
            fieldDefinition += field.apiName + ' ' + dataType;
        }
        if(!String.isEmpty(fieldDefinition)){
            if(!isLast)
                fieldDefinition += ', ';
            fieldDefinition += '\n';   
        }
        return fieldDefinition;
    }
    
    private static List<String> getObjectInOrderToCreate(Map<String, ObjectWrapper> sObjectWithReferences){
        List<String> objectsInOrderToCreate = new List<String>();
        for(String apiName : sObjectWithReferences.keySet()){
            ObjectWrapper obj = sObjectWithReferences.get(apiName);
            if(obj.referencedFields != null && obj.referencedFields.size() > 0){
                for(String fieldName : obj.referencedFields){
                    FieldWrapper field = obj.fields.get(fieldName);
                    if(!objectsInOrderToCreate.contains(field.referencedObjectApiName))
                        objectsInOrderToCreate.add(field.referencedObjectApiName); 
                }
            }
        }
        for(String apiName : sObjectWithReferences.keySet()){
            if(!objectsInOrderToCreate.contains(apiName))
                objectsInOrderToCreate.add(apiName); 
        }
        return objectsInOrderToCreate;
    }
    
    private static Map<String, ObjectWrapper> getSobjectWithReferencesMap(List<String> sObjectList){
        Map<String, ObjectWrapper> referenceMap = new Map<String, ObjectWrapper>();
        for(String objectType : sObjectList){
            ObjectWrapper objWrapper = new ObjectWrapper();
            objWrapper.apiName = objectType;
            objWrapper.referencedFields = new List<String>();
            objWrapper.fields = new Map<String, FieldWrapper>();
         	Map<String,Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get(objectType).getDescribe().fields.getMap();
            for(Schema.SObjectField field : fieldsMap.values()){
                FieldWrapper fieldWrapper = new FieldWrapper();
                fieldWrapper.apiName = field.getDescribe().getName();
                if(String.valueOf(field.getDescribe().getType()) == 'reference'){
                    objWrapper.referencedFields.add(fieldWrapper.apiName);
                    for(SobjectType sObj : field.getDescribe().getReferenceTo()){
                        String objName = String.valueOf(sObj.getDescribe().getSobjectType());
                        if(sObjectList.contains(objName)){
                            fieldWrapper.referencedObjectApiName = objName;
                            break; 
                        }
                    }
                    fieldWrapper.relationshipName = field.getDescribe().getRelationshipName();
                }
                objWrapper.fields.put(fieldWrapper.apiName, fieldWrapper);
            }
            referenceMap.put(objWrapper.apiName, objWrapper);
        }
        return referenceMap;
    }  
}