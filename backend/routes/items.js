const express = require('express');
const multer = require('multer');

const Item = require('../models/Item');
const { uploadBuffer } = require('../config/cloudinary');

const router = express.Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

// POST /api/items — multipart/form-data with fields:
// barcode, name, brand, quantity, price, source, sourceImageUrl (all strings)
// productPhoto, barcodePhoto (files)
router.post(
  '/',
  upload.fields([
    { name: 'productPhoto', maxCount: 1 },
    { name: 'barcodePhoto', maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      const productPhotoFile = req.files?.productPhoto?.[0];
      const barcodePhotoFile = req.files?.barcodePhoto?.[0];
      if (!productPhotoFile || !barcodePhotoFile) {
        return res.status(400).json({ message: 'productPhoto and barcodePhoto are both required' });
      }

      const { barcode, name, brand, quantity, price, source, sourceImageUrl } = req.body;
      if (!barcode || !name) {
        return res.status(400).json({ message: 'barcode and name are required' });
      }

      const [productPhotoUrl, barcodePhotoUrl] = await Promise.all([
        uploadBuffer(productPhotoFile.buffer, 'product_scanner/products'),
        uploadBuffer(barcodePhotoFile.buffer, 'product_scanner/barcodes'),
      ]);

      const item = await Item.create({
        barcode,
        name,
        brand,
        quantity,
        price,
        source,
        sourceImageUrl,
        productPhotoUrl,
        barcodePhotoUrl,
      });

      res.status(201).json(item);
    } catch (err) {
      console.error('Error creating item:', err);
      res.status(500).json({ message: 'Failed to save item', error: err.message });
    }
  },
);

router.get('/', async (req, res) => {
  const items = await Item.find().sort({ createdAt: -1 });
  res.json(items);
});

module.exports = router;
