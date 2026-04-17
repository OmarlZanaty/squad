const sharp = require('sharp');

const path = require('path');

const fs = require('fs');

const { saveToLocal } = require('./localStorage');
/**
 * Image sizes configuration
 * Each size is optimized for different use cases
 */
const IMAGE_SIZES = {
    thumbnail: {
        width: 150,
        height: 150,
        quality: 85,
        description: 'Thumbnail for list view'
    },
    medium: {
        width: 600,
        height: 600,
        quality: 90,
        description: 'Medium size for feed display'
    },
    large: {
        width: 1200,
        height: 1200,
        quality: 92,
        description: 'Large size for detail view'
    }
};

/**
 * Process and upload image to S3 with multiple sizes
 * @param {Buffer} imageBuffer - Image file buffer
 * @param {string} originalFilename - Original filename
 * @param {string} folder - S3 folder path
 * @returns {Promise<Object>} Object containing URLs for all image sizes
 */
async function processAndUploadImage(imageBuffer, originalFilename, folder = 'posts/media') {
    try {
        console.log('🖼️ Starting image processing for:', originalFilename);
        
        // Generate unique filename
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const fileExtension = path.extname(originalFilename).toLowerCase();
        const baseName = path.basename(originalFilename, fileExtension);
        
        // Get image metadata
        const metadata = await sharp(imageBuffer).metadata();
        console.log('📊 Image metadata:', { width: metadata.width, height: metadata.height, format: metadata.format });
        
        const imageUrls = {
            original: null,
            thumbnail: null,
            medium: null,
            large: null,
            metadata: {
                width: metadata.width,
                height: metadata.height,
                format: metadata.format,
                size: imageBuffer.length,
                processedAt: new Date().toISOString()
            }
        };

        // Upload original image to archive
        const originalKey = `${folder}/original/${baseName}-${uniqueSuffix}.webp`;
        const originalBuffer = await sharp(imageBuffer)
            .webp({ quality: 95, lossless: true })
            .toBuffer();
        
        imageUrls.original = saveToLocal(originalBuffer, originalKey);
        console.log('✅ Original image uploaded');

        // Process each size
        for (const [sizeName, sizeConfig] of Object.entries(IMAGE_SIZES)) {
            try {
                console.log(`🔄 Processing ${sizeName} (${sizeConfig.width}x${sizeConfig.height})...`);
                
                // Resize and compress image
                const resizedBuffer = await sharp(imageBuffer)
                    .resize(sizeConfig.width, sizeConfig.height, {
                        fit: 'cover',
                        position: 'center'
                    })
                    .webp({ quality: sizeConfig.quality })
                    .toBuffer();

                // Save to local storage
                const s3Key = `${folder}/${sizeName}/${baseName}-${uniqueSuffix}.webp`;
                imageUrls[sizeName] = saveToLocal(resizedBuffer, s3Key);
                
                // Calculate compression ratio
                const compressionRatio = ((1 - resizedBuffer.length / imageBuffer.length) * 100).toFixed(2);
                console.log(`✅ ${sizeName} uploaded - Size: ${(resizedBuffer.length / 1024).toFixed(2)}KB, Compression: ${compressionRatio}%`);
            } catch (error) {
                console.error(`❌ Error processing ${sizeName}:`, error.message);
                throw error;
            }
        }

        console.log('✨ Image processing complete');
        return imageUrls;
    } catch (error) {
        console.error('❌ Image processing error:', error);
        throw new Error(`Image processing failed: ${error.message}`);
    }
}

/**
 * Upload buffer to S3
 * @param {Buffer} buffer - File buffer
 * @param {string} key - S3 object key
 * @param {string} contentType - MIME type
 * @returns {Promise<Object>} S3 upload response
 */


/**
 * Generate LQIP (Low Quality Image Placeholder) for progressive loading
 * @param {Buffer} imageBuffer - Image file buffer
 * @param {string} originalFilename - Original filename
 * @param {string} folder - S3 folder path
 * @returns {Promise<string>} LQIP data URL
 */
async function generateLQIP(imageBuffer, originalFilename, folder = 'posts/media') {
    try {
        console.log('🎨 Generating LQIP...');
        
        // Create a very small, blurred version
        const lqipBuffer = await sharp(imageBuffer)
            .resize(50, 50, { fit: 'cover' })
            .blur(5)
            .webp({ quality: 50 })
            .toBuffer();

        // Convert to base64 data URL
        const lqipDataUrl = `data:image/webp;base64,${lqipBuffer.toString('base64')}`;
        console.log('✅ LQIP generated');
        
        return lqipDataUrl;
    } catch (error) {
        console.error('❌ LQIP generation error:', error);
        throw new Error(`LQIP generation failed: ${error.message}`);
    }
}

/**
 * Extract image metadata without uploading
 * @param {Buffer} imageBuffer - Image file buffer
 * @returns {Promise<Object>} Image metadata
 */
async function extractImageMetadata(imageBuffer) {
    try {
        const metadata = await sharp(imageBuffer).metadata();
        
        return {
            width: metadata.width,
            height: metadata.height,
            format: metadata.format,
            colorspace: metadata.space,
            hasAlpha: metadata.hasAlpha,
            size: imageBuffer.length,
            estimatedCompressedSize: Math.round(imageBuffer.length * 0.15) // Rough estimate
        };
    } catch (error) {
        console.error('❌ Metadata extraction error:', error);
        throw new Error(`Metadata extraction failed: ${error.message}`);
    }
}

module.exports = {
    processAndUploadImage,
    generateLQIP,
    extractImageMetadata,
    IMAGE_SIZES,
    
};
