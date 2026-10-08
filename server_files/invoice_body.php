<!-- Seller & Customer Info -->
            <div class="section">
                <div class="section-title">
                    <i class="fas fa-user-tie"></i>
                    معلومات الأطراف
                </div>
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">البائع</div>
                        <div class="info-value"><?php echo $order['seller_name']; ?></div>
                        <div class="info-label" style="margin-top: 10px;">رقم الهاتف</div>
                        <div class="info-value"><?php echo $order['seller_phone']; ?></div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">العميل</div>
                        <div class="info-value"><?php echo $order['customer_name']; ?></div>
                        <div class="info-label" style="margin-top: 10px;">رقم الهاتف</div>
                        <div class="info-value"><?php echo $order['customer_phone']; ?></div>
                    </div>
                </div>
            </div>

            <!-- Shipping Info -->
            <?php if (!empty($order['ship_fullname'])): ?>
            <div class="section">
                <div class="section-title">
                    <i class="fas fa-shipping-fast"></i>
                    معلومات الشحن
                </div>
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">الاسم</div>
                        <div class="info-value"><?php echo $order['ship_fullname']; ?></div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">رقم الهاتف</div>
                        <div class="info-value"><?php echo $order['ship_mobile']; ?></div>
                    </div>
                    <?php if (!empty($order['ship_email'])): ?>
                    <div class="info-item">
                        <div class="info-label">البريد الإلكتروني</div>
                        <div class="info-value"><?php echo $order['ship_email']; ?></div>
                    </div>
                    <?php endif; ?>
                    <div class="info-item">
                        <div class="info-label">العنوان</div>
                        <div class="info-value">
                            <?php 
                                $address_parts = [];
                                if (!empty($order['ship_city'])) $address_parts[] = $order['ship_city'];
                                if (!empty($order['ship_country'])) $address_parts[] = $order['ship_country'];
                                if (!empty($order['ship_zone'])) $address_parts[] = 'منطقة ' . $order['ship_zone'];
                                if (!empty($order['ship_street'])) $address_parts[] = 'شارع ' . $order['ship_street'];
                                if (!empty($order['ship_building'])) $address_parts[] = 'مبنى ' . $order['ship_building'];
                                echo implode(', ', $address_parts);
                            ?>
                        </div>
                    </div>
                </div>
            </div>
            <?php endif; ?>

            <!-- Items -->
            <div class="section">
                <div class="section-title">
                    <i class="fas fa-shopping-cart"></i>
                    المنتجات
                </div>
                <table class="items-table">
                    <thead>
                        <tr>
                            <th>المنتج</th>
                            <th>السعر</th>
                            <th>الكمية</th>
                            <th>المجموع</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if ($items && is_array($items)): ?>
                            <?php foreach ($items as $item): ?>
                                <tr>
                                    <td><?php echo htmlspecialchars($item['name']); ?></td>
                                    <td><?php echo number_format($item['price'], 2); ?> ريال</td>
                                    <td><?php echo $item['quantity']; ?></td>
                                    <td><?php echo number_format($item['price'] * $item['quantity'], 2); ?> ريال</td>
                                </tr>
                            <?php endforeach; ?>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>

            <!-- Total -->
            <div class="total-section">
                <div class="total-label">💰 المبلغ الإجمالي</div>
                <div class="total-amount"><?php echo number_format($order['total_amount'], 2); ?> ريال</div>
            </div>