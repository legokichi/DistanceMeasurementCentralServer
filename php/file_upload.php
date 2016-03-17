<?php
    $uploaddir = '../uploads/';
    /*
        {
            "filename": "hoge.wav"
        }
    */
    if(!isset($_POST['filename']) ||
       !isset($_FILES['file'])
    ) { // 入力がない
        http_response_code(500);
        echo json_encode(array('error' => 'Invalid parameter'));
        die();
    }
    if(filesize($_FILES['file']['tmp_name']) == 0
    ) { // ファイルが空
        http_response_code(500);
        echo json_encode(array('error' => 'Empty file'));
        die();
    }

    $filename = $_POST['filename'];
    $filedata = $_FILES['file'];

    // upload file
    if(!move_uploaded_file($filedata['tmp_name'], $uploaddir . $filename)) {
        http_response_code(500);
        echo json_encode(array('error' => 'Cannot save illust'));
        exit();
    }


    // responce
    http_response_code(204);
?>
