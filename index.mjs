import {S3Client, GetObjectCommand, PutObjectCommand} from "@aws-sdk/client-s3"

const client = new S3Client({region: "us-east-1"});

export const handler = async (event) => {
  
  try {
    
    for (const record of event.Records) {
      
      console.log("Iniciando processamento de mensagem.", record)
      
      const rawBody = JSON.parse(record.body)
      const bodyMessage = JSON.parse(rawBody.Message)
      const ownerId = bodyMessage.ownerId;
      
      try {
        var bucketName = "terraformer-s3bucket-catalog-item"
        var filename = `${ownerId}-catalog.json`
        const catalog = await getS3Object(bucketName, filename);
        const catalogData = JSON.parse(catalog)
        
        if (bodyMessage.type == "product") { updateOrAddItem(catalogData.products, bodyMessage) }
        if (bodyMessage.type == "category") { updateOrAddItem(catalogData.categories, bodyMessage) }
        if (bodyMessage.type == "remove-product") { itemDelete (catalogData.products, bodyMessage ) }
        if (bodyMessage.type == "remove-category") { itemDelete (catalogData.categories, bodyMessage) }
        
        
        await putS3Object(bucketName, filename, JSON.stringify(catalogData))
        
        
      } catch (error) {
        
        if(error.message == "Error getting object from bucket") {
          
          if (bodyMessage.type.startsWith("remove")) {
            console.log("This file does not exist.", filename)
            return {status: "not-found"}
            
          } else {
          
            const newCatalog = { products: [], categories: [] } 
            if (bodyMessage.type == "product") {
              newCatalog.products.push(bodyMessage)
            } else {
              newCatalog.categories.push(bodyMessage)
            }
          
          await putS3Object(bucketName, filename, JSON.stringify(newCatalog))  
          }

        } else if (error.message == "Não foi possível encontrar esse item."){
          
          console.log("Erro ao remover um item!", error, bodyMessage)
          return { status: "not-found" }
          
        } else {
          throw error;
        }
      }
    }
    
    return {status: 'sucesso'}
  } catch(error) {
    console.log("Error", error)
    throw new Error("Erro ao processar mensagem SQS.")
  }
};


async function getS3Object(bucket, key) {
  
  const getCommand = new GetObjectCommand({
    Bucket: bucket,
    Key: key
  });
  
  try {
    
    const response = await client.send(getCommand);
    
    // Ler o stream e converter para string.
    return streamToString(response.Body)
    
  } catch (error) {
    throw new Error('Error getting object from bucket');
  }
}




async function putS3Object(targetBucket, targetKey, content) {
  
  try {
    const putCommand = new PutObjectCommand({
      Bucket: targetBucket, 
      Key: targetKey,
      Body: content, 
      ContentType: "application/json"
    });
    
    const putResult = await client.send(putCommand)
    
    return putResult;
    
  } catch (error) {
    console.log(error);
    return;
  }
}







function updateOrAddItem(catalog, newItem) {
  const index = catalog.findIndex(item => item.id === newItem.id);
  if(index !== -1) {
    catalog[index] = {...catalog[index], ...newItem};
  } else {
    catalog.push(newItem);
  }
}



function streamToString(stream) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    stream.on('data', (chunk) => chunks.push(chunk));
    stream.on('end', () => resolve(Buffer.concat(chunks).toString('utf-8')));
    stream.on('error', reject);
  });
}

function itemDelete(catalogArray, theItem) {

  const index = catalogArray.findIndex(item => item.id === theItem.id);
  if (index !== -1) {
    catalogArray.splice(index, 1)
  } else {
    throw new Error("Não foi possível encontrar esse item.");
  }
}