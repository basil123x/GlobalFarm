<?php
// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Set HTML header
header('Content-Type: text/html; charset=utf-8');

$conn = mysqli_connect("localhost", "cdagvlmy_Globee", "A122%133z.", "cdagvlmy_Globee");

// Get order ID from URL
$order_id = isset($_GET['order_id']) ? (int)$_GET['order_id'] : 0;
// GlobalFarm store_id = 2 (default for this app). Martit = 1.
$store_id = isset($_GET['store_id']) ? preg_replace('/[^0-9]/', '', $_GET['store_id']) : '2';
if ($store_id === '') {
    $store_id = '2';
}

if ($order_id <= 0) {
    die('رقم الطلب غير صحيح');
}

// Fetch order details
$sql = "SELECT 
    Orders.*,
    seller.Fullname as seller_name,
    seller.PhoneNumber as seller_phone,
    customer.Fullname as customer_name,
    customer.PhoneNumber as customer_phone,
    Shipping_Orders.Fullname as ship_fullname,
    Shipping_Orders.MobileNumber as ship_mobile,
    Shipping_Orders.Email as ship_email,
    Shipping_Orders.Country as ship_country,
    Shipping_Orders.City as ship_city,
    Shipping_Orders.`Zone Number` as ship_zone,
    Shipping_Orders.`Street Number` as ship_street,
    Shipping_Orders.`Building Number` as ship_building
FROM Orders 
LEFT JOIN Users as seller ON Orders.uid = seller.uid
LEFT JOIN Users as customer ON Orders.cust_id = customer.uid
LEFT JOIN Shipping_Orders ON Orders.ship_id = Shipping_Orders.id
WHERE Orders.id = $order_id";

$result = $conn->query($sql);

if (!$result || $result->num_rows == 0) {
    die('الطلب غير موجود');
}

$order = $result->fetch_assoc();
$items = json_decode($order['items'], true);

// Brand theme by store
$is_globalfarm = ($store_id === '2');
$brand_primary = $is_globalfarm ? '#4A7C3F' : '#CC0000';
$brand_secondary = $is_globalfarm ? '#3A6230' : '#0055A4';
$brand_name = $is_globalfarm ? 'Global Farm' : 'Martit';
$brand_logo = $is_globalfarm
    ? 'https://www.Globee-Trading.com/app2026/assets/img/globalfarm_logo.png'
    : 'https://www.Globee-Trading.com/app2026/assets/img/martit_logo.png';
// Fallback to shared logo if store-specific file missing on older deploys
$brand_logo_fallback = '../../../assets/img/Logo.png';
?>

<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>فاتورة #<?php echo $order['oid']; ?></title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
    @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@200..1000&display=swap');
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: "Cairo", sans-serif;
            background: #ffffff;
            padding: 20px;
            min-height: 100vh;
        }

        .invoice-container {
            max-width: 900px;
            margin: 0 auto;
            background: white;
            border: 2px solid #e0e0e0;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
            overflow: hidden;
        }

        .invoice-header {
            background: linear-gradient(135deg, <?php echo $brand_primary; ?> 0%, <?php echo $brand_secondary; ?> 100%);
            color: white;
            padding: 30px 40px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .header-logo {
            max-width: 70px;
            height: auto;
            background: white;
            padding: 10px;
            border-radius: 8px;
        }

        .header-info {
            text-align: center;
            flex-grow: 1;
        }

        .header-info h1 {
            font-size: 28px;
            margin-bottom: 8px;
            font-weight: 700;
        }

        .header-info p {
            font-size: 16px;
            opacity: 0.95;
        }

        .header-status {
            text-align: left;
        }

        .invoice-body {
            padding: 35px 40px;
        }

        .section {
            margin-bottom: 25px;
        }

        .section-title {
            font-size: 18px;
            font-weight: 700;
            color: <?php echo $brand_primary; ?>;
            margin-bottom: 15px;
            padding-bottom: 8px;
            border-bottom: 2px solid <?php echo $brand_secondary; ?>;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .info-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 15px;
        }

        .info-item {
            background: #f8f9fb;
            padding: 15px;
            border-radius: 8px;
            border-right: 3px solid <?php echo $brand_primary; ?>;
        }

        .info-label {
            font-size: 12px;
            color: #666;
            margin-bottom: 5px;
            font-weight: 500;
        }

        .info-value {
            font-size: 15px;
            font-weight: 600;
            color: #333;
        }

        .items-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
            background: white;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            overflow: hidden;
        }

        .items-table th {
            background: linear-gradient(135deg, <?php echo $brand_primary; ?> 0%, <?php echo $brand_secondary; ?> 100%);
            color: white;
            padding: 12px 15px;
            text-align: right;
            font-weight: 600;
            font-size: 14px;
        }

        .items-table td {
            padding: 12px 15px;
            border-bottom: 1px solid #f0f0f0;
            font-size: 14px;
        }

        .items-table tbody tr:hover {
            background: #f8f9fb;
        }

        .items-table tbody tr:last-child td {
            border-bottom: none;
        }

        .total-section {
            background: linear-gradient(135deg, <?php echo $brand_primary; ?> 0%, <?php echo $brand_secondary; ?> 100%);
            color: white;
            padding: 25px 30px;
            border-radius: 10px;
            margin-top: 25px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .total-label {
            font-size: 18px;
            font-weight: 600;
        }

        .total-amount {
            font-size: 20px;
            font-weight: 700;
        }

        .status-badge {
            display: inline-block;
            padding: 6px 16px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 600;
        }

        .status-pending {
            background: #fff3cd;
            color: #856404;
        }

        .status-completed {
            background: #d4edda;
            color: #155724;
        }

        .status-cancelled {
            background: #f8d7da;
            color: #721c24;
        }

        .invoice-footer {
            background: #f8f9fb;
            padding: 25px 40px;
            border-top: 3px solid #00BCD4;
        }

        .footer-content {
            display: flex;
            justify-content: space-around;
            align-items: center;
            flex-wrap: wrap;
            gap: 20px;
            margin-bottom: 15px;
        }

        .footer-item {
            display: flex;
            align-items: center;
            gap: 8px;
            color: #333;
            font-size: 13px;
            font-weight: 500;
        }

        .footer-item i {
            color: #0055A4;
            font-size: 16px;
        }

        .footer-note {
            margin-top: 15px;
            padding-top: 15px;
            border-top: 1px solid #e0e0e0;
            font-size: 12px;
            color: #666;
            text-align: center;
        }

        .print-button {
            background: linear-gradient(135deg, #0055A4 0%, #00BCD4 100%);
            color: white;
            border: none;
            padding: 14px 40px;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            margin: 20px auto;
            display: block;
            transition: all 0.3s;
            box-shadow: 0 4px 12px rgba(0, 85, 164, 0.3);
        }

        .print-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 16px rgba(0, 85, 164, 0.4);
        }

        .page-container {
            width: 210mm;
            height:100vh;
            margin: 0 auto;
            background: transparent;
            overflow:auto;
            -ms-overflow-style: none;
            scrollbar-width: none;
        }
        .page-header-screen {
            background:url("../../../assets/img/print/header.png");
            background-size:cover;
            background-repeat:no-repeat;
            width:auto;
            height:114px;
        }
        
        .page-footer-screen {
            border-top:2px solid #CE2020;
        }

        .con i {
            color:#B4545A;
        }

        .content {
            position:relative;
        }

        .content .logo, td .logo {
            position:fixed;
            top:50%;
            left:50%;
            transform:translate(-50%, -50%);
            opacity: 0.1;
            z-index:-1;
        }

        @media print {
            @page {
                size: A4 portrait;
                margin: 0;
            }

            * {
                -webkit-print-color-adjust: exact !important;
                print-color-adjust: exact !important;
            }

            html, body {
                width: 210mm;
                height: 297mm;
                margin: 0;
                padding: 0;
            }

            .print-button {
                display: none !important;
            }

            /* الحاوية الرئيسية */
            .page-container {
                width: 100%;
                margin: 0;
                background: transparent;
            }

            /* إخفاء الهيدر والفوتر الخاصين بالشاشة */
            .page-header-screen,
            .page-footer-screen {
                display: none !important;
            }

            /* الجدول الرئيسي للصفحة */
            .print-layout-table {
                display: table;
                width: 100%;
                border-collapse: collapse;
            }

            .print-layout-table thead {
                display: table-header-group;
            }

            .print-layout-table tbody {
                display: table-row-group;
            }

            .print-layout-table tfoot {
                display: table-footer-group;
            }

            /* الهيدر - يتكرر في كل صفحة */
            .print-header {
                background:url("../../../assets/img/print/header.png");
                background-size:cover;
                background-repeat:no-repeat;
                width:auto;
                height:114px;
            }

            /* الفوتر - يتكرر في كل صفحة */
            .print-footer {
                border-top:2px solid #CE2020;
                text-align: center;
                padding: 15px;
            }

            .print-footer p {
                font-size: 10px;
                margin: 3px 0;
                color: white !important;
            }

            /* المحتوى - يكمل تلقائياً */
            .print-content {
                padding: 20px;
            }

        }

        @media print {
            @page {
                size: A4;
                margin: 15mm;
            }

            body {
                background: white;
                padding: 0;
                margin: 0;
            }

            .invoice-container {
                box-shadow: none;
                border: none;
                border-radius: 0;
                max-width: 100%;
            }

            .invoice-header {
                position: running(header);
            }

            .invoice-footer {
                position: running(footer);
            }

            .print-button {
                display: none;
            }

            .section {
                page-break-inside: avoid;
            }

            .items-table {
                page-break-inside: auto;
            }

            .items-table thead {
                display: table-header-group;
            }

            .items-table tr {
                page-break-inside: avoid;
                page-break-after: auto;
            }

            .total-section {
                page-break-inside: avoid;
            }
        }

        @media (max-width: 768px) {
            .invoice-header {
                flex-direction: column;
                gap: 15px;
                text-align: center;
            }

            .header-logo {
                max-width: 100px;
            }

            .header-status {
                text-align: center;
            }

            .info-grid {
                grid-template-columns: 1fr;
            }

            .header-info h1 {
                font-size: 22px;
            }

            .total-section {
                flex-direction: column;
                gap: 10px;
                text-align: center;
            }

            .total-amount {
                font-size: 26px;
            }

            .footer-content {
                flex-direction: column;
                gap: 10px;
            }

            .items-table {
                font-size: 12px;
            }

            .items-table th,
            .items-table td {
                padding: 8px 10px;
            }
        }
    </style>
</head>
<body>
    <table class="print-layout-table" style="display: none;">
        <thead>
            <tr>
                <td>
                    <div class="print-header"><?include('invoice_head.php');?></div>
                </td>
            </tr>
        </thead>
        <tfoot>
            <tr>
                <td><?include('invoice_footer.php');?></td>
            </tr>
        </tfoot>
        <tbody>
            <tr>
                <td>
                    <div class="logo"><img src="../../../assets/img/print/logo.png" alt=""></div>
                    <?include($contract_url);?>
                </td>
            </tr>
        </tbody>
    </table>

    <button class="print-button" onclick="window.print()">
        <i class="fas fa-print"></i> طباعة الفاتورة
    </button>
</body>
</html>

<?php
$conn->close();
?>