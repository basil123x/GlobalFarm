<img src="../../../assets/img/Logo.png?k=<?=time();?>" alt="Globee Trading Logo" class="header-logo">
    <div class="header-info">
        <h1>🧾 فاتورة رقم #<?php echo $order['oid']; ?></h1>
        <p>تاريخ الفاتورة: <?php echo date('Y-m-d', strtotime($order['created_at'])); ?></p>
    </div>
    <div class="header-status">
        <span class="status-badge status-<?php echo $order['status']; ?>">
            <?php 
                switch($order['status']) {
                    case 'pending': echo '⏳ قيد المعالجة'; break;
                    case 'completed': echo '✅ مكتمل'; break;
                    case 'cancelled': echo '❌ ملغي'; break;
                    default: echo $order['status'];
                }
            ?>
        </span>
    </div>