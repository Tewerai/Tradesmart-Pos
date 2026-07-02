<?php
include "../d.php";
include "session.php";
include "scan.php";

if (isset($_POST['search'])) {
   $ame = $_POST['search'];

   // Check if the search term is "all" to display all products
   if ($ame === "all") {
       $query = "SELECT * FROM `retail products` WHERE `shopid`='" . $_SESSION['user_id'] . "'";
   } else {
       // Search by product name
       $query = "SELECT * FROM `retail products` WHERE name LIKE '%$ame%' AND `shopid`='" . $_SESSION['user_id'] . "'";
   }

   $result = mysqli_query($con, $query);

   // Check if there are any results
   if ($result->num_rows > 0) {
       while ($row = $result->fetch_assoc()) {
           ?>
           <tr class="text-white">
               <td>
                   <span class="view-text"><?php echo $row['name']; ?></span>
                   <input type="text" class="edit-input product_name" value="<?php echo $row['name']; ?>">
               </td>
               <td>
                   <span class="view-text"><?php echo $row['quantity']; ?></span>
                   <input type="number" class="edit-input product_quantity" value="<?php echo $row['quantity']; ?>">
               </td>
               <td>
                   <span class="view-text"><?php echo $row['price']; ?></span>
                   <input type="number" class="edit-input product_price" value="<?php echo $row['price']; ?>">
               </td>
               <td>
                   <span class="view-text"><?php echo $row['stock price']; ?></span>
                   <input type="number" class="edit-input stock_price" value="<?php echo ($row['stock price'] != 0) ? $row['stock price'] : ''; ?>">
               </td>
               <td><button class="edit-row">Edit</button></td>
               <td><button class="delete-row">Delete</button></td>
               <input type="hidden" class="product_id" value="<?php echo $row['id']; ?>">
               <input type="hidden" class="product_serial" value="<?php echo $row['serial']; ?>">
           </tr>
           <?php
       }
   } else {
       echo "<tr><td colspan='6'>No products found.</td></tr>";
   }
}
if (isset($_POST['searchi'])) {
   $ame = $_POST['searchi'];
   $query = "SELECT*FROM `retail products` WHERE name LIKE '%$ame%' AND `shopid`='".$_SESSION['user_id']."'";
   $result = mysqli_query($con, $query);
   while ($row = $result->fetch_assoc()) {
       ?>
    <tr>
        <!-- Display product details in text format -->
        <td class="view-text"><?php echo $row['name']; ?></td>
        <td class="view-text"><?php echo $row['quantity']; ?></td>
        <td class="view-text"><?php echo $row['price']; ?></td>
        <td class="view-text"><?php echo $row['stock_price']; ?></td>
        
        <!-- Edit button to enable editing mode -->
        <td>
            <button type="button" class="edit-row">Edit</button>
            <input type="hidden" class="product_id" value="<?php echo $row['id']; ?>">
            <input type="hidden" class="product_serial" value="<?php echo $row['serial id']; ?>">
        </td>
    </tr>
   <?php 
     #close if
     }} 


if (isset($_POST['searchstock'])) {
   $ame = $_POST['searchstock'];
   $query = "SELECT*FROM `retail products` WHERE name LIKE '%$ame%' AND `shopid`='".$_SESSION['user_id']."'";
   $result = mysqli_query($con, $query);
   while ($row = $result->fetch_assoc()) {
     $sold = 0;
     $item_rev=mysqli_query($con, "SELECT*FROM `retail products` where  `shopid`='".$_SESSION['user_id']."' AND `name`='".$row['name']."' ")or die('Error In Session1'.mysqli_error($con));
     while($row_item_rev=$item_rev->fetch_assoc()){
       $sold = $sold+$row_item_rev['product revenue'];
     
     }
       $sold=$sold;
       $_SESSION['sold']=$sold;
       ?>
							<tr>
                  <td  id='product_name'><?php echo $row['name']?></td>
                  <td id='product_quantity'><?php echo $row['quantity']?></td>
                  <td  id='product_price'><?php echo $row['price']?></td>
                  <td  id='product_price'><?php echo $_SESSION['sold']?></td>
                  <td  id='product_price'><?php echo $row['amount sold']?></td>
                      <td id='category'>
       <select class="form-select" onchange="updateCategory(this)">
          <?php
          // Assume $row['product category'] contains the current category of the product.
          $currentCategory = $row['product category'];

          // Fetch unique categories from the user's products
          $unique_categories_query = "SELECT DISTINCT `product category` FROM `retail products` WHERE `shopid`='".$_SESSION['user_id']."'";
          $unique_categories_result = mysqli_query($con, $unique_categories_query) or die(mysqli_error($con));

          // Populate dropdown with unique categories
          while ($category_row = mysqli_fetch_assoc($unique_categories_result)) {
              // Check if this option matches the current category of the product
              $selected = ($category_row['product category'] == $currentCategory) ? "selected" : "";
              echo "<option value='".$category_row['product category']."' $selected>".$category_row['product category']."</option>";
          }
          ?>
      </select>
      <input type="hidden" class="serial" value="<?php echo $row['serial id']; ?>" />

    </td>
                  
              </tr>
   <?php 
     #close if
     }} 

if (isset($_POST['search_products'])) {
   $ame = $_POST['search_products'];
   $query = "SELECT*FROM `regular products` WHERE name LIKE '%$ame%'";
   $result = mysqli_query($con, $query);
   while ($row = $result->fetch_assoc()) {
       ?>
			<div class="item-select" id="commodity" style="text-align:center;">
             <input type="checkbox" id="item-selected" value="<?php echo $row['serial id']?>" />
              
              <img src="<?php echo  $row['image url']?>" style="width:100%;height:100px;" />
              <p><?php echo  $row['name']?></p>
            </div>
   <?php 
     #close if
     }} 

if (isset($_POST['add_stock_price'])){
  	   $query = "SELECT*FROM `retail products` WHERE id='".$_POST['id']."'";
   	   $result = mysqli_query($con, $query);
  	   $row = $result->fetch_assoc();
  	   $price = 0 ;
       $price = $row['quantity']+$row['amount sold'];
       $price = $price*$_POST['add_stock_price'];
       $que = "UPDATE `retail products` SET  `amount spent`='$price',`stock price`='".$_POST['add_stock_price']."' where id=1";
  	   mysqli_query($con, $que);
}

if (isset($_POST['what_to_view'])){
  
	if ($_POST['what_to_view'] == 'profits') {
        // Calculate total revenue from completed orders
        $revenue_query = mysqli_query($con, "SELECT `total` FROM `retailers complete orders` WHERE `shopid` = '" . $_SESSION['user_id'] . "' ") or die('Error in fetching revenue'. mysqli_error($con));
        
        $total_revenue = 0;
        while ($row = $revenue_query->fetch_assoc()) {
            $total_revenue += $row['total'] ?? 0; // Avoid null values
        }
    
        // Calculate total spent on stock from retail products
        $spent_query = mysqli_query($con, "SELECT `amount spent` FROM `retail products` WHERE `shopid` = '" . $_SESSION['user_id'] . "'") or die('Error in fetching spent amount' . mysqli_error($con));
        
        $total_spent = 0;
        while ($r = $spent_query->fetch_assoc()) {
            $total_spent += $r['amount spent'] ?? 0; // Avoid null values
        }
    
        // Calculate profit
        $profit = $total_revenue - $total_spent;
        ?>
    
            <thead>
                <tr class="text-white">
                    <th scope="col">Amount Spent On Products</th>
                    <th scope="col">Amount Made</th>
                    <th scope="col">Profit</th>
                </tr>
            </thead>
            <tbody>
                <tr class="text-white">
                    <th scope="col"><?php echo $_SESSION['moneysign'] . $total_spent; ?></th>
                    <th scope="col"><?php echo $_SESSION['moneysign'] . $total_revenue; ?></th>
                    <th scope="col"><?php echo $_SESSION['moneysign'] . $profit; ?></th>
                </tr>
            </tbody>
    
        <?php
    }
     else if($_POST['what_to_view']=='top_sellers'){
     $for_made_return=mysqli_query($con, "SELECT*FROM `retailers history` where `shopid`='".$_SESSION['user_id']."' AND `order-status`='complete' ")or die('Error In Session 1'.mysqli_error($con));
     	$for_spent=mysqli_query($con, "SELECT*FROM `retail products` where `shopid`='".$_SESSION['user_id']."' ORDER BY `product revenue` DESC ")or die('Error In Session 1'.mysqli_error($con));
      ?>
		
		    <thead>
            <tr class="text-white">
                <th scope="col">Products Name</th>
                <th scope="col">Amount Sold</th>
              <th scope="col">Profits</th>
            </tr>
            </thead>
           <tbody>
             <?php while($row=$for_spent->fetch_assoc()){?>
             <tr class="text-white">
                <th scope="col"><?php echo $row['name'];?></th>
                <th scope="col"><?php echo $row['amount sold'];?></th>
                <th scope="col"><?php echo $_SESSION['moneysign'].$row['amount sold']*$row['price'];?></th>
            </tr>
            <?php }?>
          </tbody>

<?php
       
}
  	  else if($_POST['what_to_view']=='low_sellers'){
        $for_made_return=mysqli_query($con, "SELECT*FROM `retailers history` where `shopid`='".$_SESSION['user_id']."' AND `order-status`='complete' ")or die('Error In Session 1'.mysqli_error($con));
     	$for_spent=mysqli_query($con, "SELECT*FROM `retail products` where `shopid`='".$_SESSION['user_id']."' ORDER BY `product revenue` ASC ")or die('Error In Session 1'.mysqli_error($con));
      ?>
		
		    <thead>
            <tr class="text-white">
                <th scope="col">Products Name</th>
                <th scope="col">Amount Sold (Units Moved)</th>
              <th scope="col">Profits</th>
            </tr>
            </thead>
           <tbody>
             <?php while($row=$for_spent->fetch_assoc()){?>
             <tr class="text-white">
                <th scope="col"><?php echo $row['name'];?></th>
                <th scope="col"><?php echo $row['amount sold'];?></th>
                <th scope="col"><?php echo $_SESSION['moneysign'].$row['amount sold']*$row['price'];?></th>
            </tr>
            <?php }?>
          </tbody>

<?php
       }
  	  else if($_POST['what_to_view']=="low_items"){
        $for_low_items=mysqli_query($con, "SELECT * FROM `retail products` WHERE `shopid` = '".$_SESSION['user_id']."' AND CAST(`quantity` AS SIGNED) < 5 ORDER BY CAST(`quantity` AS SIGNED) ASC") or die('Error In Session 1'.mysqli_error($con));
        $for_spent=mysqli_query($con, "SELECT*FROM `retail products` where `shopid`='".$_SESSION['user_id']."' ORDER BY `product revenue` ASC ")or die('Error In Session 1'.mysqli_error($con));
      ?>
		
		    <thead>
            <tr class="text-white">
                <th scope="col">Products Name</th>
                <th scope="col">Available</th>
            </tr>
            </thead>
           <tbody>
             <?php while($row=$for_low_items->fetch_assoc()){?>
             <tr class="text-white">
                <th scope="col"><?php echo $row['name'];?></th>
                <th scope="col"><?php echo $row['quantity'];?></th>
            </tr>
            <?php }?>
          </tbody>

<?php
       }
  	  else if($_POST['what_to_view']=="expenses"){
           $expenseTotal = 0;
        $expenses=mysqli_query($con, "SELECT * FROM `expense` WHERE `shopid` = '".$_SESSION['user_id']."'") or die('Error In Session 1'.mysqli_error($con));
      ?>
		
		    <thead>

            <tr class="text-white">
                <th scope="col">Expense Name</th>
                <th scope="col">Value</th>
                <th scope="col">Date</th>
                <th scope="col">Time</th>
            </tr>
            </thead>
           <tbody>
             <?php while($row=$expenses->fetch_assoc()){ $expenseTotal+=$row['amount']?>
             <tr class="text-white">
                <th scope="col"><?php echo $row['expense name'];?></th>
                <th scope="col"><?php echo $_SESSION["moneysign"].$row['amount'];?></th>
                <th scope="col"><?php echo $row['date'];?></th>
                <th scope="col"><?php echo $row['time'];?></th>
            </tr>
              <script>
                $('#orderTitle').html('Expenses Total');
                $('#orders').html("<?php echo  $_SESSION["moneysign"]; echo $expenseTotal; ?>");

          </script>
            <?php }?>

          </tbody>

<?php
       }
  	  else if($_POST['what_to_view']=='recent'){
           $total = 0;
           $orders=0;
           $jsDateTS = strtotime($_POST['date']);
          $date = date('l jS \of F Y', $jsDateTS );
          $products_of_the_day=mysqli_query($con, "SELECT*FROM `retailers complete orders` where `shopid`='".$_SESSION['user_id']."' AND
  `date`='$date'")or die('Error In Session 1'.mysqli_error($con));
  
      ?>
		
                            <thead>
                                <tr class="text-white">
                                    <th scope="col">Items</th>
                                    <th scope="col">Amount</th>
                                    <th scope="col">Receipt Id</th>
                                    <th scope="col">Time</th>
                                    <th scope="col">Action</th>

                                </tr>
                            </thead>
           <tbody>
            <?php  while($roww= $products_of_the_day->fetch_assoc()){$total+=$roww['total']; $orders++;?>
                              <tr class="text-white">
<td class="text-white">
    <?php
    // Unserialize the 'products' data
    $items = unserialize($roww['products']);
    
    // Check if unserialization was successful and that we have an array
    if ($items && is_array($items)) {
        foreach ($items as $productName => $quantity) {
            // If productName is 0, set it to 1 (as per your logic)
            if ($productName == 0) {
                $productName = 1;
            }
            echo "<span id='productName'>" . htmlspecialchars($productName) . "</span>";
            echo " <span id='productQuantity'> x " . htmlspecialchars($quantity) . '</span><br>';
        }
    } else {
        echo "No items found.";
    }
    ?>
</td>

                                <td><?php echo $_SESSION['moneysign'].$roww['total']?></td>
                                <td><?php echo $roww['order-number']?></td>
                                <td><?php echo $roww['time']?></td>
                                <td><button id='refund'>Refund</button><input type="hidden" value="<?php echo $roww['id'];?>"/></td>

                              </tr>
                              <script>  $('#dayTotal').html("<?php echo $_SESSION['moneysign'] . $total; ?>");</script>

                              <script>$('#orders').html(<?php echo $orders;?>)</script>
             <?php }?>
          </tbody>

<?php
       
}
}
if (isset($_POST['searchpro'])) {
   $ame = $_POST['searchpro'];
   $query = "SELECT*FROM `retail products` WHERE name LIKE '%$ame%' AND `shopid`='".$_SESSION['user_id']."'";
   $result = mysqli_query($con, $query);
   while ($row = $result->fetch_assoc()) {
       ?>
           <input type="text" value="<?php echo $row['name']?>" id="code-err" readonly/>
			<input type="hidden" value="<?php echo $row['serial id']?>" id="code-err" readonly/>
   <?php 
   }}

  if (isset($_POST['add_stock_price_with_onchange'])) {
	$sqli = "UPDATE `retail products` SET `stock price`='".$_POST['add_stock_price_with_onchange']."' WHERE `id`='".$_POST['id']."'";
    mysqli_query($con, $sqli);
  }       


  if (isset($_POST['add_sell_price_with_onchange'])) {
	$sqli = "UPDATE `retail products` SET `price`='".$_POST['add_sell_price_with_onchange']."' WHERE `id`='".$_POST['id']."'";
    mysqli_query($con, $sqli);
  }       

 if (isset($_POST['add_product_with_onchange'])) {
	$sqli = "UPDATE `retail products` SET `quantity`='".$_POST['add_product_with_onchange']."' WHERE `id`='".$_POST['id']."'";
    mysqli_query($con, $sqli);
  }    

  if (isset($_POST['add_stock_prize'])) {
  $query = "SELECT*FROM `retail products`  WHERE `id`='".$_POST['id']."'";
   $result = mysqli_query($con, $query);
    $res = $result->fetch_assoc();
    $spent = $res['quantity']*$res['stock price'];
	$sqli = "UPDATE `retail products` SET `amount spent`='$spent' WHERE `id`='".$_POST['id']."'";
    mysqli_query($con, $sqli);
  }     

	if (isset($_POST['add_stock_prize_two'])) {
   $sqli = "UPDATE `retail products` SET `quantity`='".$_POST['productq']."' WHERE `id`='".$_POST['id']."' ";
    mysqli_query($con, $sqli);
  $query = "SELECT*FROM `retail products`  WHERE `id`='".$_POST['id']."'";
   $result = mysqli_query($con, $query);
    $res = $result->fetch_assoc();
    $spent = $res['quantity']*$res['stock price'];
	$sqli = "UPDATE `retail products` SET `amount spent`='$spent' WHERE `id`='".$_POST['id']."'";
    mysqli_query($con, $sqli);
  }  
?>


<script src="https://code.jquery.com/jquery-3.4.1.min.js"></script>
<script src="js/ajax.js"></script>
<script>  var refundButtons = document.querySelectorAll('#refund');

// Attach click event listener to each refund button
refundButtons.forEach(function (button) {
    button.addEventListener('click', function () {
        // Prompt user for refund reason and refunder's name
        var refundReason = prompt("Please provide a reason for the refund:");
        var refunderName = prompt("Please enter your name as the refunder:");

        // Check if the user entered a reason and a refunder name
        if (refundReason !== null && refunderName !== null) {
            // Send the refund reason and refunder's name to the server using AJAX or fetch
            var orderId = this.nextElementSibling.value;
            console.log(orderId, refundReason, refunderName);
            sendRefundReason(orderId, refundReason, refunderName);
        }
    });
});

// Function to send refund reason and refunder's name to the server (replace with your actual server-side endpoint)
function sendRefundReason(orderId, refundReason, refunderName) {
    // You can use AJAX or fetch to send data to the server
    // Replace the URL with your actual server-side endpoint
    var url = 'scan.php';

    $.ajax({
url:"scan.php",
    method:"POST",
    data:{
          refund: refundReason,
            refunderName: refunderName,
            orderId: orderId,
    },
    dataType:"text",
    success:function(data)
    {
      alert('okay');
      location.reload();
    }
});

}</script>
